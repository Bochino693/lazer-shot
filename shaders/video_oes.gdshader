shader_type canvas_item;

// Quadro do vídeo decodificado pelo hardware do Android (MediaPlayer ->
// SurfaceTexture -> ExternalTexture). Textura externa do Android: só pode ser
// lida por samplerExternalOES. Usado só na TV Box (scripts/video_nativo.gd).

uniform samplerExternalOES video;
uniform bool virar = false;   // se o aparelho entregar o quadro de cabeça para baixo

void fragment() {
	vec2 uv = virar ? vec2(UV.x, 1.0 - UV.y) : UV;
	COLOR = vec4(texture(video, uv).rgb, 1.0) * COLOR;
}
