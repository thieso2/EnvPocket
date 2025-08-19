class Envpocket < Formula
  desc "Secure environment file storage for macOS using the native keychain"
  homepage "https://github.com/thieso2/EnvPocket"
  url "https://github.com/thieso2/EnvPocket/releases/download/v0.1/envpocket-macos.tar.gz"
  sha256 "98eb3b85791b2bb8673a37c9eb5cda7e37323c3660c770b97477f69553e1a0c0"
  license "MIT"
  version "0.1"

  depends_on :macos

  def install
    bin.install "envpocket"
  end

  test do
    # Test that the binary runs and shows usage
    assert_match "Usage:", shell_output("#{bin}/envpocket 2>&1", 1)
    
    # Test the list command (should work without any saved keys)
    assert_match(/envpocket entries|No envpocket entries/, shell_output("#{bin}/envpocket list"))
  end
end