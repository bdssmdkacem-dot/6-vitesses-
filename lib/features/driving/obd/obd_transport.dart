abstract interface class ObdTransport {
  Future<void> connect();
  Future<void> connectToAddress(String address);
  Future<void> disconnect();
  Future<String> send(String command);
  bool get connected;
}
