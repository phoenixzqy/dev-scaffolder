#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "CLI Tools (rg, fd, fzf, bat, zoxide, cmake)"

$pkgs = @(
    @{ Id = "BurntSushi.ripgrep.MSVC"; Name = "ripgrep (rg)"  },
    @{ Id = "sharkdp.fd";              Name = "fd"            },
    @{ Id = "junegunn.fzf";            Name = "fzf"           },
    @{ Id = "sharkdp.bat";             Name = "bat"           },
    @{ Id = "ajeetdsouza.zoxide";      Name = "zoxide"        },
    @{ Id = "Kitware.CMake";           Name = "CMake"         }
)
foreach ($p in $pkgs) {
    Install-WingetPackage -Id $p.Id -DisplayName $p.Name
}
