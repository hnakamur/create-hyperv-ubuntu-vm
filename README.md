create-hyperv-ubuntu-vm
=======================

Hyper-VでUbuntuの仮想マシン(以下 VM と略)を作るPowerShellスクリプトです。

## 事前準備

### PowerShell のポリシー変更

[実行ポリシーについて - PowerShell | Microsoft Docs](https://docs.microsoft.com/ja-jp/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.1)

管理者権限でPowerShellを開き、以下のコマンドを実行して現在の実行ポリシーを確認します。

```powershell
Get-ExecutionPolicy
```

`Unrestricted` になってない場合は、以下のコマンドでカレントユーザーをスコープとして `Unrestricted` にします。

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
```

確認プロンプトが出るので y と Enter を押します。

実行例。

```
PS C:\users\hnakamur\hyperv-vm> Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
実行ポリシーの変更
実行ポリシーは、信頼されていないスクリプトからの保護に役立ちます。実行ポリシーを変更すると、about_Execution_Policies のヘルプ トピック (https://go.microsoft.com/fwlink/?LinkID=135170)
で説明されているセキュリティ上の危険にさらされる可能性があります。実行ポリシーを変更しますか?
[Y] はい(Y)  [A] すべて続行(A)  [N] いいえ(N)  [L] すべて無視(L)  [S] 中断(S)  [?] ヘルプ (既定値は "N"): y
```

設定後再度

```powershell
Get-ExecutionPolicy
```

を実行し `Unrestricted` になったことを確認します。

### このレポジトリのをダウンロード

以下のコマンドを実行してこのレポジトリのファイルをダウンロードします。

```powershell
Invoke-WebRequest "https://github.com/hnakamur/create-hyperv-ubuntu-vm/archive/refs/heads/main.zip" -OutFile "${Env:USERPROFILE}\Downloads\create-hyperv-ubuntu-vm.zip"
```

ダウンロードしたzipファイルを展開します。

```powershell
Expand-Archive -LiteralPath "${Env:USERPROFILE}\Downloads\create-hyperv-ubuntu-vm.zip"
```

展開したディレクトリに移動します。

```powershell
cd create-hyperv-ubuntu-vm
```

### 必要なファイル群のダウンロードと展開

必要なファイル群をダウンロードと展開します。
ダウンロードするファイルのバージョンや展開場所などを変更したい場合は `download-dependencies.ps1` の内容を適宜変更してください。

```powershell
.\download-dependencies.ps1
```

## 仮想ネットワークインタフェースを作成

静的なIPアドレスを使用したいので、デフォルトの `vEthernet (Default Switch)` とは別に仮想ネットワークインタフェースを作成します。

このレポジトリの mk-winnat.ps1 ファイルは "vEthernet (WinNAT)" という名前で 192.168.254.1/24 というアドレスで作成するようになっています。
必要に応じて適宜変更してください。

mk-winnat.ps1 ファイルを実行して Hyper-V の VM 用の仮想ネットワークインタフェースを作成します。

```powershell
.\mk-winnat.ps1
```

インタフェース名を変えた場合は launch.ps1 ファイルの `$virtualSwitchName = "WinNAT"` の部分も vEthernet の後の括弧の中身に
合わせて変えてください。

### WSL2 と Hyper-V の VM 間で通信できるようにする設定

[After converting to WSL2 no longer able to route traffic to other VSwitches on the same host. · Issue #4288 · microsoft/WSL](https://github.com/microsoft/WSL/issues/4288)
の
[コメント](https://github.com/microsoft/WSL/issues/4288#issuecomment-652259640)
を参考に設定したら通信できるようになりました。

事前状態確認

```powershell
Get-NetIPInterface | select InterfaceAlias,AddressFamily,ConnectionState,Forwarding | Where-Object {$_.InterfaceAlias -match "^vEthernet"} | Sort-Object -Property InterfaceAlias,AddressFamily | Format-Table 
```

出力例

```
PS C:\users\hnakamur\Downloads\hyperv-vm> Get-NetIPInterface | select InterfaceAlias,AddressFamily,ConnectionState,Forwarding | Where-Object {$_.InterfaceAlias -match "^vEthernet"} | Sort-Object -Property InterfaceAlias,AddressFamily | Format-Table
InterfaceAlias             AddressFamily ConnectionState Forwarding
--------------             ------------- --------------- ----------
vEthernet (Default Switch)          IPv4       Connected   Disabled
vEthernet (Default Switch)          IPv6       Connected   Disabled
vEthernet (WinNAT)                  IPv4       Connected   Disabled
vEthernet (WinNAT)                  IPv6       Connected   Disabled
vEthernet (WSL)                     IPv4       Connected   Disabled
vEthernet (WSL)                     IPv6       Connected   Disabled
```

`vEthernet (WSL)` と `vEthernet (WinNAT)` の `-Forwarding` を `Enabled` に変更。

```powershell
Set-NetIPInterface -InterfaceAlias "vEthernet (WSL)" -Forwarding Enabled
Set-NetIPInterface -InterfaceAlias "vEthernet (WinNAT)" -Forwarding Enabled
```

事後状態確認

```powershell
Get-NetIPInterface | select InterfaceAlias,AddressFamily,ConnectionState,Forwarding | Where-Object {$_.InterfaceAlias -match "^vEthernet"} | Sort-Object -Property InterfaceAlias,AddressFamily | Format-Table
```

出力例

```
PS C:\users\hnakamur\Downloads\hyperv-vm> Get-NetIPInterface | select InterfaceAlias,AddressFamily,ConnectionState,Forwarding | Where-Object {$_.InterfaceAlias -match "^vEthernet"} | Sort-Object -Property InterfaceAlias,AddressFamily | Format-Table
InterfaceAlias             AddressFamily ConnectionState Forwarding
--------------             ------------- --------------- ----------
vEthernet (Default Switch)          IPv4       Connected   Disabled
vEthernet (Default Switch)          IPv6       Connected   Disabled
vEthernet (WinNAT)                  IPv4       Connected    Enabled
vEthernet (WinNAT)                  IPv6       Connected    Enabled
vEthernet (WSL)                     IPv4       Connected    Enabled
vEthernet (WSL)                     IPv6       Connected    Enabled
```

## VMを作成と起動

### launch.ps1 スクリプトの編集

VMを作成と起動するスクリプトは launch.ps1 です。

VMの名前を変更する場合は `$VMName = "primary"` の箇所を適宜変更してください。

ディスクのサイズ上限を変更したい場合は `Resize-VHD -Path $vhdx -SizeBytes 100GB` を適宜変更してください。
ディスクファイルのサイズは使用量に応じて可変で大きくなるので、100GBと指定してもいきなりそのサイズのファイルが作られるわけではないです。

メモリサイズを変更したい場合は `New-VM` の `-MemoryStartupBytes 4096mb` を適宜変更してください。

### user-data ファイルの編集

`user-data` は cloud-init 用のデータファイルです。

`runcmd` の `sudo -u ubuntu sh -c 'echo "ssh-ed25519 _YOUR_SSH_PUBLIC_KEY_HERE_" > /home/ubuntu/.ssh/authorized_keys'` の
`_YOUR_SSH_PUBLIC_KEY_HERE_` の部分を自分のssh公開鍵に書き換えます。

VMのIPアドレスやVMで使用するDNSサーバーを変更したい場合は `write_files:` の `path: /etc/netplan/51-netcfg.yaml` のエントリの
`content:` を適宜変更します。

このレポジトリの `user-data` では VM の IPv4 アドレスは `192.168.254.2/24` で、DNSサーバーは Google Pulbic DNS を使うように
しています。

`ubuntu` ユーザーのパスワードを変えたい場合は `password: ubuntu` の部分を変更します。

### launch.ps1 スクリプトの実行

```powershell
.\launch.ps1
```

実行すると Hyper-V の VM のウィンドウが開いてVMが起動されます。
ログインプロンプトが出てからログインできるようになるまで1分程度かかります
(どうやらログインプロンプトが出てから cloud-init が実行されている模様)。

そこでPowerShell の画面で以下のコマンドを実行して ping が通るようになるまで待ち、
応答が返るようになったら Ctrl-C で止めます。

```powershell
ping -t 192.168.254.2
```

## VM へ ssh でログイン

WSL1 か WSL2 のシェル（あるいは [OpenSSH をインストールする | Microsoft Docs](https://docs.microsoft.com/ja-jp/windows-server/administration/openssh/openssh_install_firstuse)
で OpenSSH Client をインストール済みであればコマンドプロンプトやPowerShellでもOK）を開いて、
以下のコマンドを実行してsshでログインします。

```bash
ssh ubuntu@192.168.254.2
```

## VM の削除

設定値を試行錯誤している間は VM の削除と作成・起動を繰り返すので削除用のスクリプト delete-vm.ps1 を用意しました。

VMの名前を変更していた場合は `$VMName = "primary"` の箇所を適宜変更してください。

管理者権限のPowerShellで以下のように実行すると、VMを停止後削除します。

```powershell
.\delete-vm.ps1
```

## 事後準備

普段は PowerShell で未署名のスクリプトを使わないようであれば、管理者権限の PowerShell で以下のコマンドを実行してポリシーを `Restricted` に戻しておきます。

```powershell
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
```

