# MIT License
#
# Copyright (c) 2024 thieso2
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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