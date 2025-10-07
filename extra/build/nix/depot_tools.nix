stdenv.mkDerivation {
  pname = "depot_tools";
  version = "1.0.0"; # You can specify a version if needed

  src = builtins.fetchGit {
    url = "https://chromium.googlesource.com/chromium/tools/depot_tools.git";
  };

  meta = with lib; {
    description = "Chromium depot_tools for managing dependencies";
    homepage = "https://commondatastorage.googleapis.com/chromium-browser-docs/depot_tools.html";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yourGitHubUsername ];
  };
}