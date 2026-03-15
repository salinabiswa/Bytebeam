class Config {
  static const int discoveryPort        = 49316;
  static const int controlPort          = 49317;
  static const int dataPortBase         = 49318;
  static const int numParallelChannels  = 4;
  static const int chunkSize            = 4 * 1024 * 1024;
  static const int smallFileThreshold   = 512 * 1024;
  static const int socketSendBufferSize = 8 * 1024 * 1024;
  static const int discoveryIntervalSec = 2;
  static const int deviceTimeoutSec     = 8;
  static const String protocolVersion   = 'BYTEBEAM_1.0';
  static const int magicNumber          = 0xBEAB0001;
  static const int chunkHeaderSize      = 20;
  static const String appName           = 'ByteBeam';
  static const String bundleName        = '__bytebeam_bundle__.zip';
}
