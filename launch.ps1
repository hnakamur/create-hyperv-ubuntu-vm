# This script is based on
# https://github.com/BenjaminArmstrong/Hyper-V-PowerShell/blob/8d166e1c2ba71c2b5120bc5490ea9be01891ec74/Ubuntu-VM-Build/BaseUbuntuBuild.ps1
# and modified for Ubuntu focal.

# Download from http://cloud-images.ubuntu.com/releases/focal/release/
$imgPath = "${Env:USERPROFILE}\Downloads\ubuntu-20.04-server-cloudimg-amd64.img"

$VMName = "primary"
$virtualSwitchName = "WinNAT"
$vmPath = "${Env:Public}\Documents\Hyper-V\$VMName"

$vhdx = "$($vmPath)\test.vhdx"
$cloudInitIso = "$($vmPath)\metadata.iso"

New-Item "$vmPath" -type directory -Force | Out-Null
& .\cloudinitiso.exe -iso $cloudInitIso

# Download qemu-img from http://www.cloudbase.it/qemu-img-windows/
# and extract it to C:\qemu-img
& C:\qemu-img\qemu-img convert -f qcow2 $imgPath -O vhdx -o subformat=dynamic $vhdx
Resize-VHD -Path $vhdx -SizeBytes 100GB

# Create new virtual machine and start it
new-vm $VMName -MemoryStartupBytes 4096mb -VHDPath $vhdx -Generation 1 `
               -SwitchName $virtualSwitchName -Path $vmPath | Out-Null
set-vm -Name $VMName -ProcessorCount 2
Set-VMDvdDrive -VMName $VMName -Path $cloudInitIso
Start-VM $VMName

# Open up VMConnect
Invoke-Expression "vmconnect.exe localhost `"$VMName`""
