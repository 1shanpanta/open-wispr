class OpenWispr < Formula
  desc "Push-to-talk voice dictation for macOS using Whisper"
  homepage "https://github.com/human37/open-wispr"
  url "https://github.com/human37/open-wispr.git", tag: "v0.34.0"
  license "MIT"

  bottle do
    root_url "https://github.com/human37/open-wispr/releases/download/v0.34.0"
    sha256 cellar: :any, arm64_sequoia: "2abefb6c489a419b1283742da5a9c68fd45109641b7a9dd55c0a9c1bc9943a49"
  end

  depends_on "whisper-cpp"
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    system "bash", "scripts/bundle-app.sh", ".build/release/open-wispr", "OpenWispr.app", version.to_s
    bin.install ".build/release/open-wispr"
    prefix.install "OpenWispr.app"
  end

  # Install a real bundle at ~/Applications/OpenWispr.app (not a symlink into
  # the versioned Cellar path) so macOS TCC grants — Accessibility, Input
  # Monitoring, Microphone — keep referring to the same path across upgrades.
  # Upgrades rsync into the existing bundle so the directory inode is reused.
  def post_install
    target = Pathname.new("#{Dir.home}/Applications/OpenWispr.app")
    target.dirname.mkpath

    target.unlink if target.symlink?

    if target.exist?
      system "rsync", "-a", "--delete", "#{prefix}/OpenWispr.app/", "#{target}/"
    else
      cp_r prefix/"OpenWispr.app", target
    end
  end

  service do
    run ["#{Dir.home}/Applications/OpenWispr.app/Contents/MacOS/open-wispr", "start"]
    keep_alive successful_exit: false
    log_path var/"log/open-wispr.log"
    error_log_path var/"log/open-wispr.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      Recommended: use the install script for guided setup:
        curl -fsSL https://raw.githubusercontent.com/human37/open-wispr/main/scripts/install.sh | bash

      Or start manually:
        brew services start open-wispr

      Grant Accessibility and Microphone when prompted.
      The Whisper model downloads automatically (~142 MB).
    EOS
  end

  test do
    assert_match "open-wispr", shell_output("#{bin}/open-wispr --help")
  end
end
