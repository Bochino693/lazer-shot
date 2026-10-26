package org.lazershot;

import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.graphics.YuvImage;
import android.hardware.Camera;
import android.os.Handler;
import android.os.HandlerThread;

import java.io.File;
import java.io.FileOutputStream;
import java.util.List;

/**
 * A FOTO DO JOGADOR na TV Box (Android 7), pela API clássica de câmera do
 * Android (é por ela que as TV Box publicam a webcam USB).
 *
 * O jogo (Godot 3.6) chama estes métodos estáticos pelo JavaClassWrapper,
 * só com números e texto, e nunca espera: tudo acontece numa linha própria
 * e o jogo pergunta o estado depois. Nada aqui lança erro para fora: um
 * erro vira o texto de status() (aparece só na CONFIGURAÇÃO).
 *
 *   cameras()            quantas câmeras o Android vê
 *   abrir(indice)        liga a câmera (a imagem começa a chegar)
 *   quadros()            quantos quadros já chegaram desde abrir
 *   fotografar(caminho)  grava o último quadro em JPEG nesse arquivo
 *   foto()               0 nada, 1 gravando, 2 pronta, -1 falhou
 *   fechar()             solta a câmera (sem gastar processador)
 *   status()             o que aconteceu, em palavras
 */
public final class CameraFoto {
    private static final Object TRAVA = new Object();
    private static HandlerThread linha;
    private static Handler mao;
    private static Camera camera;
    private static SurfaceTexture superficie;
    private static byte[] quadro;
    private static int largura;
    private static int altura;
    private static int formato;
    private static volatile int quadros;
    private static volatile int estadoFoto;
    private static volatile String status = "parada";

    private CameraFoto() {
    }

    public static int cameras() {
        try {
            return Camera.getNumberOfCameras();
        } catch (Throwable t) {
            status = "sem câmera: " + t;
            return -1;
        }
    }

    public static String status() {
        return status;
    }

    public static int quadros() {
        return quadros;
    }

    public static int foto() {
        return estadoFoto;
    }

    public static int largura() {
        return largura;
    }

    public static int altura() {
        return altura;
    }

    public static boolean abrir(final int indice) {
        try {
            garantirLinha();
            quadros = 0;
            status = "abrindo";
            mao.post(new Runnable() {
                public void run() {
                    abrirAgora(indice);
                }
            });
            return true;
        } catch (Throwable t) {
            status = "não abriu: " + t;
            return false;
        }
    }

    public static boolean fotografar(final String caminho) {
        try {
            garantirLinha();
            estadoFoto = 1;
            mao.post(new Runnable() {
                public void run() {
                    gravarAgora(caminho);
                }
            });
            return true;
        } catch (Throwable t) {
            estadoFoto = -1;
            status = "foto falhou: " + t;
            return false;
        }
    }

    public static boolean fechar() {
        try {
            if (mao == null) {
                return true;
            }
            mao.post(new Runnable() {
                public void run() {
                    fecharAgora();
                    status = "parada";
                }
            });
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    private static void garantirLinha() {
        if (linha == null) {
            linha = new HandlerThread("LazerCamera");
            linha.start();
            mao = new Handler(linha.getLooper());
        }
    }

    private static void abrirAgora(int indice) {
        fecharAgora();
        try {
            camera = Camera.open(indice);
            Camera.Parameters p = camera.getParameters();
            Camera.Size melhor = escolher(p.getSupportedPreviewSizes());
            if (melhor != null) {
                p.setPreviewSize(melhor.width, melhor.height);
            }
            p.setPreviewFormat(ImageFormat.NV21);
            try {
                camera.setParameters(p);
            } catch (Throwable t) {
                // a câmera USB pode recusar: fica com o que ela já usa
            }
            p = camera.getParameters();
            Camera.Size s = p.getPreviewSize();
            largura = s.width;
            altura = s.height;
            formato = p.getPreviewFormat();
            superficie = new SurfaceTexture(10);
            camera.setPreviewTexture(superficie);
            int bits = ImageFormat.getBitsPerPixel(formato);
            if (bits <= 0) {
                bits = 16;
            }
            int tamanho = largura * altura * bits / 8;
            for (int i = 0; i < 3; i++) {
                camera.addCallbackBuffer(new byte[tamanho]);
            }
            camera.setPreviewCallbackWithBuffer(new Camera.PreviewCallback() {
                public void onPreviewFrame(byte[] dados, Camera c) {
                    if (dados == null) {
                        return;
                    }
                    synchronized (TRAVA) {
                        if (quadro == null || quadro.length != dados.length) {
                            quadro = new byte[dados.length];
                        }
                        System.arraycopy(dados, 0, quadro, 0, dados.length);
                    }
                    quadros++;
                    try {
                        c.addCallbackBuffer(dados);
                    } catch (Throwable t) {
                        // a câmera fechou no meio
                    }
                }
            });
            camera.startPreview();
            status = "aberta " + largura + "x" + altura + " formato " + formato;
        } catch (Throwable t) {
            status = "não abriu: " + t;
            fecharAgora();
        }
    }

    /** O tamanho mais perto de 640x480 (pouco processador e boa foto). */
    private static Camera.Size escolher(List<Camera.Size> lista) {
        if (lista == null) {
            return null;
        }
        Camera.Size melhor = null;
        int nota = Integer.MAX_VALUE;
        for (int i = 0; i < lista.size(); i++) {
            Camera.Size s = lista.get(i);
            int n = Math.abs(s.width - 640) + Math.abs(s.height - 480);
            if (n < nota) {
                nota = n;
                melhor = s;
            }
        }
        return melhor;
    }

    private static void gravarAgora(String caminho) {
        byte[] copia;
        synchronized (TRAVA) {
            copia = quadro == null ? null : quadro.clone();
        }
        if (copia == null) {
            estadoFoto = -1;
            status = "foto sem imagem (nenhum quadro chegou)";
            return;
        }
        FileOutputStream saida = null;
        try {
            if (formato != ImageFormat.NV21 && formato != ImageFormat.YUY2) {
                estadoFoto = -1;
                status = "formato de imagem " + formato + " sem foto";
                return;
            }
            File tmp = new File(caminho + ".tmp");
            saida = new FileOutputStream(tmp);
            YuvImage img = new YuvImage(copia, formato, largura, altura, null);
            boolean ok = img.compressToJpeg(new Rect(0, 0, largura, altura), 88, saida);
            saida.close();
            saida = null;
            File fim = new File(caminho);
            if (fim.exists()) {
                fim.delete();
            }
            if (ok && tmp.renameTo(fim)) {
                estadoFoto = 2;
                status = "foto gravada " + largura + "x" + altura;
            } else {
                estadoFoto = -1;
                status = "foto não gravou";
            }
        } catch (Throwable t) {
            estadoFoto = -1;
            status = "foto falhou: " + t;
        } finally {
            if (saida != null) {
                try {
                    saida.close();
                } catch (Throwable t) {
                    // nada
                }
            }
        }
    }

    private static void fecharAgora() {
        Camera c = camera;
        camera = null;
        if (c != null) {
            try {
                c.setPreviewCallbackWithBuffer(null);
            } catch (Throwable t) {
                // nada
            }
            try {
                c.stopPreview();
            } catch (Throwable t) {
                // nada
            }
            try {
                c.release();
            } catch (Throwable t) {
                // nada
            }
        }
        if (superficie != null) {
            try {
                superficie.release();
            } catch (Throwable t) {
                // nada
            }
            superficie = null;
        }
    }
}
