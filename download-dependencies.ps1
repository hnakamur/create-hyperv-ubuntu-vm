# https://cloudbase.it/downloads/ から qemu-img の Windows 版の zip ファイルを
# ダウンロードして C:\qemu-img に展開。
Invoke-WebRequest "https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip" -OutFile "${Env:USERPROFILE}\Downloads\qemu-img-win-x64-2_3_0.zip"
Expand-Archive -LiteralPath "${Env:USERPROFILE}\Downloads\qemu-img-win-x64-2_3_0.zip" -DestinationPath "C:\qemu-img"

# cloudinitiso.exe をダウンロード。
Invoke-WebRequest "http://github.com/hnakamur/create-hyperv-ubuntu-vm/releases/download/v0.1.0/cloudinitiso.exe" -OutFile "cloudinitiso.exe"

# Ubuntu 20.04 LTS サーバー版のイメージファイルをダウンロード。
Invoke-WebRequest "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img" -OutFile "${Env:USERPROFILE}\Downloads\ubuntu-20.04-server-cloudimg-amd64.img"
