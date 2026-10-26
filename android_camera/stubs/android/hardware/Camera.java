package android.hardware;
public class Camera {
    public static int getNumberOfCameras() { throw new RuntimeException("stub"); }
    public static Camera open(int cameraId) { throw new RuntimeException("stub"); }
    public Parameters getParameters() { throw new RuntimeException("stub"); }
    public void setParameters(Parameters params) { throw new RuntimeException("stub"); }
    public final void setPreviewTexture(android.graphics.SurfaceTexture surfaceTexture) throws java.io.IOException { throw new RuntimeException("stub"); }
    public final void addCallbackBuffer(byte[] callbackBuffer) { throw new RuntimeException("stub"); }
    public final void setPreviewCallbackWithBuffer(PreviewCallback cb) { throw new RuntimeException("stub"); }
    public final void startPreview() { throw new RuntimeException("stub"); }
    public final void stopPreview() { throw new RuntimeException("stub"); }
    public final void release() { throw new RuntimeException("stub"); }
    public interface PreviewCallback {
        void onPreviewFrame(byte[] data, Camera camera);
    }
    public class Size {
        public int width;
        public int height;
    }
    public class Parameters {
        public java.util.List<Size> getSupportedPreviewSizes() { throw new RuntimeException("stub"); }
        public void setPreviewSize(int width, int height) { throw new RuntimeException("stub"); }
        public Size getPreviewSize() { throw new RuntimeException("stub"); }
        public void setPreviewFormat(int pixel_format) { throw new RuntimeException("stub"); }
        public int getPreviewFormat() { throw new RuntimeException("stub"); }
    }
}
