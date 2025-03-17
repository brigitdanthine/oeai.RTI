<#
.Synopsis
Activate a Python virtual environment for the current PowerShell session.

.Description
Pushes the python executable for a virtual environment to the front of the
$Env:PATH environment variable and sets the prompt to signify that you are
in a Python virtual environment. Makes use of the command line switches as
well as the `pyvenv.cfg` file values present in the virtual environment.

.Parameter VenvDir
Path to the directory that contains the virtual environment to activate. The
default value for this is the parent of the directory that the Activate.ps1
script is located within.

.Parameter Prompt
The prompt prefix to display when this virtual environment is activated. By
default, this prompt is the name of the virtual environment folder (VenvDir)
surrounded by parentheses and followed by a single space (ie. '(.venv) ').

.Example
Activate.ps1
Activates the Python virtual environment that contains the Activate.ps1 script.

.Example
Activate.ps1 -Verbose
Activates the Python virtual environment that contains the Activate.ps1 script,
and shows extra information about the activation as it executes.

.Example
Activate.ps1 -VenvDir C:\Users\MyUser\Common\.venv
Activates the Python virtual environment located in the specified location.

.Example
Activate.ps1 -Prompt "MyPython"
Activates the Python virtual environment that contains the Activate.ps1 script,
and prefixes the current prompt with the specified string (surrounded in
parentheses) while the virtual environment is active.

.Notes
On Windows, it may be required to enable this Activate.ps1 script by setting the
execution policy for the user. You can do this by issuing the following PowerShell
command:

PS C:\> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

For more information on Execution Policies: 
https://go.microsoft.com/fwlink/?LinkID=135170

#>
Param(
    [Parameter(Mandatory = $false)]
    [String]
    $VenvDir,
    [Parameter(Mandatory = $false)]
    [String]
    $Prompt
)

<# Function declarations --------------------------------------------------- #>

<#
.Synopsis
Remove all shell session elements added by the Activate script, including the
addition of the virtual environment's Python executable from the beginning of
the PATH variable.

.Parameter NonDestructive
If present, do not remove this function from the global namespace for the
session.

#>
function global:deactivate ([switch]$NonDestructive) {
    # Revert to original values

    # The prior prompt:
    if (Test-Path -Path Function:_OLD_VIRTUAL_PROMPT) {
        Copy-Item -Path Function:_OLD_VIRTUAL_PROMPT -Destination Function:prompt
        Remove-Item -Path Function:_OLD_VIRTUAL_PROMPT
    }

    # The prior PYTHONHOME:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PYTHONHOME) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME -Destination Env:PYTHONHOME
        Remove-Item -Path Env:_OLD_VIRTUAL_PYTHONHOME
    }

    # The prior PATH:
    if (Test-Path -Path Env:_OLD_VIRTUAL_PATH) {
        Copy-Item -Path Env:_OLD_VIRTUAL_PATH -Destination Env:PATH
        Remove-Item -Path Env:_OLD_VIRTUAL_PATH
    }

    # Just remove the VIRTUAL_ENV altogether:
    if (Test-Path -Path Env:VIRTUAL_ENV) {
        Remove-Item -Path env:VIRTUAL_ENV
    }

    # Just remove VIRTUAL_ENV_PROMPT altogether.
    if (Test-Path -Path Env:VIRTUAL_ENV_PROMPT) {
        Remove-Item -Path env:VIRTUAL_ENV_PROMPT
    }

    # Just remove the _PYTHON_VENV_PROMPT_PREFIX altogether:
    if (Get-Variable -Name "_PYTHON_VENV_PROMPT_PREFIX" -ErrorAction SilentlyContinue) {
        Remove-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Scope Global -Force
    }

    # Leave deactivate function in the global namespace if requested:
    if (-not $NonDestructive) {
        Remove-Item -Path function:deactivate
    }
}

<#
.Description
Get-PyVenvConfig parses the values from the pyvenv.cfg file located in the
given folder, and returns them in a map.

For each line in the pyvenv.cfg file, if that line can be parsed into exactly
two strings separated by `=` (with any amount of whitespace surrounding the =)
then it is considered a `key = value` line. The left hand string is the key,
the right hand is the value.

If the value starts with a `'` or a `"` then the first and last character is
stripped from the value before being captured.

.Parameter ConfigDir
Path to the directory that contains the `pyvenv.cfg` file.
#>
function Get-PyVenvConfig(
    [String]
    $ConfigDir
) {
    Write-Verbose "Given ConfigDir=$ConfigDir, obtain values in pyvenv.cfg"

    # Ensure the file exists, and issue a warning if it doesn't (but still allow the function to continue).
    $pyvenvConfigPath = Join-Path -Resolve -Path $ConfigDir -ChildPath 'pyvenv.cfg' -ErrorAction Continue

    # An empty map will be returned if no config file is found.
    $pyvenvConfig = @{ }

    if ($pyvenvConfigPath) {

        Write-Verbose "File exists, parse `key = value` lines"
        $pyvenvConfigContent = Get-Content -Path $pyvenvConfigPath

        $pyvenvConfigContent | ForEach-Object {
            $keyval = $PSItem -split "\s*=\s*", 2
            if ($keyval[0] -and $keyval[1]) {
                $val = $keyval[1]

                # Remove extraneous quotations around a string value.
                if ("'""".Contains($val.Substring(0, 1))) {
                    $val = $val.Substring(1, $val.Length - 2)
                }

                $pyvenvConfig[$keyval[0]] = $val
                Write-Verbose "Adding Key: '$($keyval[0])'='$val'"
            }
        }
    }
    return $pyvenvConfig
}


<# Begin Activate script --------------------------------------------------- #>

# Determine the containing directory of this script
$VenvExecPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VenvExecDir = Get-Item -Path $VenvExecPath

Write-Verbose "Activation script is located in path: '$VenvExecPath'"
Write-Verbose "VenvExecDir Fullname: '$($VenvExecDir.FullName)"
Write-Verbose "VenvExecDir Name: '$($VenvExecDir.Name)"

# Set values required in priority: CmdLine, ConfigFile, Default
# First, get the location of the virtual environment, it might not be
# VenvExecDir if specified on the command line.
if ($VenvDir) {
    Write-Verbose "VenvDir given as parameter, using '$VenvDir' to determine values"
}
else {
    Write-Verbose "VenvDir not given as a parameter, using parent directory name as VenvDir."
    $VenvDir = $VenvExecDir.Parent.FullName.TrimEnd("\\/")
    Write-Verbose "VenvDir=$VenvDir"
}

# Next, read the `pyvenv.cfg` file to determine any required value such
# as `prompt`.
$pyvenvCfg = Get-PyVenvConfig -ConfigDir $VenvDir

# Next, set the prompt from the command line, or the config file, or
# just use the name of the virtual environment folder.
if ($Prompt) {
    Write-Verbose "Prompt specified as argument, using '$Prompt'"
}
else {
    Write-Verbose "Prompt not specified as argument to script, checking pyvenv.cfg value"
    if ($pyvenvCfg -and $pyvenvCfg['prompt']) {
        Write-Verbose "  Setting based on value in pyvenv.cfg='$($pyvenvCfg['prompt'])'"
        $Prompt = $pyvenvCfg['prompt'];
    }
    else {
        Write-Verbose "  Setting prompt based on parent's directory's name. (Is the directory name passed to venv module when creating the virtual environment)"
        Write-Verbose "  Got leaf-name of $VenvDir='$(Split-Path -Path $venvDir -Leaf)'"
        $Prompt = Split-Path -Path $venvDir -Leaf
    }
}

Write-Verbose "Prompt = '$Prompt'"
Write-Verbose "VenvDir='$VenvDir'"

# Deactivate any currently active virtual environment, but leave the
# deactivate function in place.
deactivate -nondestructive

# Now set the environment variable VIRTUAL_ENV, used by many tools to determine
# that there is an activated venv.
$env:VIRTUAL_ENV = $VenvDir

$env:VIRTUAL_ENV_PROMPT = $Prompt

if (-not $Env:VIRTUAL_ENV_DISABLE_PROMPT) {

    Write-Verbose "Setting prompt to '$Prompt'"

    # Set the prompt to include the env name
    # Make sure _OLD_VIRTUAL_PROMPT is global
    function global:_OLD_VIRTUAL_PROMPT { "" }
    Copy-Item -Path function:prompt -Destination function:_OLD_VIRTUAL_PROMPT
    New-Variable -Name _PYTHON_VENV_PROMPT_PREFIX -Description "Python virtual environment prompt prefix" -Scope Global -Option ReadOnly -Visibility Public -Value $Prompt

    function global:prompt {
        Write-Host -NoNewline -ForegroundColor Green "($_PYTHON_VENV_PROMPT_PREFIX) "
        _OLD_VIRTUAL_PROMPT
    }
}

# Clear PYTHONHOME
if (Test-Path -Path Env:PYTHONHOME) {
    Copy-Item -Path Env:PYTHONHOME -Destination Env:_OLD_VIRTUAL_PYTHONHOME
    Remove-Item -Path Env:PYTHONHOME
}

# Add the venv to the PATH
Copy-Item -Path Env:PATH -Destination Env:_OLD_VIRTUAL_PATH
$Env:PATH = "$VenvExecDir$([System.IO.Path]::PathSeparator)$Env:PATH"

# SIG # Begin signature block
# MII0CwYJKoZIhvcNAQcCoIIz/DCCM/gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBALKwKRFIhr2RY
# IW/WJLd9pc8a9sj/IoThKU92fTfKsKCCG9IwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggb+MIIE5qADAgECAhMzAAGjYG80
# gDvBLzOgAAAAAaNgMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwMjExMDQwNTMxWhcNMjUwMjE0
# MDQwNTMxWjB8MQswCQYDVQQGEwJVUzEPMA0GA1UECBMGT3JlZ29uMRIwEAYDVQQH
# EwlCZWF2ZXJ0b24xIzAhBgNVBAoTGlB5dGhvbiBTb2Z0d2FyZSBGb3VuZGF0aW9u
# MSMwIQYDVQQDExpQeXRob24gU29mdHdhcmUgRm91bmRhdGlvbjCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAJyGo8jBqxeIDR/cfmPTSysGqtRuQJFqGcrn
# B32iVcChIQ/dQgBWmcy874+UIPOt6MH9m/pkwZmjCxOK5DN9weqlqkfOST3Pd3sV
# qbpzUGJx51OKra+c4t5DVUqJdhyeP8ItCdXd212zOAfqPZEX2k7lHmJLWAZyKATP
# m+7gfyF0orc+BrybENOYhFOqmvs6D0H5PpgLdQ8UDF9N+udTjTZhVJCtQgHJhxzt
# XOmaBZB1E3PaWdoRK3PWKwcJ8HlUFhmP0m3AW6AQk1mJMp3Uh+zbT2+oP2rwnEV1
# UnKpav7EJiBwJAlK6m4vCTBXgiDNqxsGXeesluia4Kq73JWmP0Ag2yJEk9RQvDhf
# W5WrOgENF5VoTIbno/kgW8qAx5liniPiWF9qNzmZPyz+V5zFkxNdI5/JQJgmLOoB
# Fe6sU4p8ANFY86GcjsfjMje/cFup/LFK3udbeTc5owuJFqwMG98c1wwWvI0LBumf
# 3OweEGtF9SiGLjqiu0elLGQE9+czFwIDAQABo4ICGTCCAhUwDAYDVR0TAQH/BAIw
# ADAOBgNVHQ8BAf8EBAMCB4AwPAYDVR0lBDUwMwYKKwYBBAGCN2EBAAYIKwYBBQUH
# AwMGGysGAQQBgjdhgqKNuwqmkohkgZH0oEWCk/3hbzAdBgNVHQ4EFgQUlWnE2IQi
# rEHDiAJZ3Tv+AOmUB1kwHwYDVR0jBBgwFoAUZZ9RzoVofy+KRYiq3acxux4NAF4w
# ZwYDVR0fBGAwXjBcoFqgWIZWaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0El
# MjAwMi5jcmwwgaUGCCsGAQUFBwEBBIGYMIGVMGQGCCsGAQUFBzAChlhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3J0MC0GCCsGAQUFBzABhiFo
# dHRwOi8vb25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwZgYDVR0gBF8wXTBRBgwr
# BgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMAgGBmeBDAEEATANBgkqhkiG
# 9w0BAQwFAAOCAgEAhMfjoB3UOVOtSsoc/SP0rs/NGeyHVGbp30qrKKAhyLEyRsg1
# rA3DnJ6zgAT5iWYTOdKxZZk0eh3zr/m/keU4hsS8qqALfMPPOAOcDY5uhH2Ax4HC
# 30D9FxKXC9X9wEfdETa1SlHaM20+sFJaxTO0K5yBAzGlkXzR+jupJsvtjPj4g+AY
# E+w3ajgvEJmy2qYaUcBcxXq4Y5gU2xqpsu+i5h0f9lk1YkAEWo69Vj3dX9UszYqt
# GamdDqpeRk3C1BK3F7cSdijIl9TB3fr5i9q2PU2ehCI3sTpIbsS61b42g5cMV8mc
# BzwH4ATlHNbO7sQWiHKMywV8x42gMBX6IOcs5lTTY3zl4ASwA2QC/jc14nO/YbPg
# Wms2HT9Bo93cI0xHJRN+2GBu29r9sMq3G4zr4UuzbMzyTGm1wH5UKXpY2FGcHcgd
# LscPsySXpGQvD68eZJ5Tbh1523Zi9lux6tIKJssD5egipQts3Z1cR00lcNEN9XYK
# BJYn8Ys2WC3NVlzKGidBF885sxtpykXWCuBicIRHy9r6yO8dtA2OdhSlYITqbtEZ
# HsSrwsFtjPegLoBKe52ONbyjl2pAlSLp++WQsJHpYLCGTJiNJFt3+1e5MBpPatN9
# iy9LinqMeKAjI5DJw6VlbVyIa2bTdqRDEKzuIQzze8Z57GbPL5Uusu+101kwggda
# MIIFQqADAgECAhMzAAAABft6XDITYd9dAAAAAAAFMA0GCSqGSIb3DQEBDAUAMGMx
# CzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xNDAy
# BgNVBAMTK01pY3Jvc29mdCBJRCBWZXJpZmllZCBDb2RlIFNpZ25pbmcgUENBIDIw
# MjEwHhcNMjEwNDEzMTczMTUzWhcNMjYwNDEzMTczMTUzWjBaMQswCQYDVQQGEwJV
# UzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNy
# b3NvZnQgSUQgVmVyaWZpZWQgQ1MgRU9DIENBIDAyMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA0hqZfD8ykKTA6CDbWvshmBpDoBf7Lv132RVuSqVwQO3a
# ALLkuRnnTIoRmMGo0fIMQrtwR6UHB06xdqOkAfqB6exubXTHu44+duHUCdE4ngjE
# LBQyluMuSOnHaEdveIbt31OhMEX/4nQkph4+Ah0eR4H2sTRrVKmKrlOoQlhia73Q
# g2dHoitcX1uT1vW3Knpt9Mt76H7ZHbLNspMZLkWBabKMl6BdaWZXYpPGdS+qY80g
# DaNCvFq0d10UMu7xHesIqXpTDT3Q3AeOxSylSTc/74P3og9j3OuemEFauFzL55t1
# MvpadEhQmD8uFMxFv/iZOjwvcdY1zhanVLLyplz13/NzSoU3QjhPdqAGhRIwh/YD
# zo3jCdVJgWQRrW83P3qWFFkxNiME2iO4IuYgj7RwseGwv7I9cxOyaHihKMdT9Neo
# SjpSNzVnKKGcYMtOdMtKFqoV7Cim2m84GmIYZTBorR/Po9iwlasTYKFpGZqdWKyY
# nJO2FV8oMmWkIK1iagLLgEt6ZaR0rk/1jUYssyTiRqWr84Qs3XL/V5KUBEtUEQfQ
# /4RtnI09uFFUIGJZV9mD/xOUksWodGrCQSem6Hy261xMJAHqTqMuDKgwi8xk/mfl
# r7yhXPL73SOULmu1Aqu4I7Gpe6QwNW2TtQBxM3vtSTmdPW6rK5y0gED51RjsyK0C
# AwEAAaOCAg4wggIKMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADAd
# BgNVHQ4EFgQUZZ9RzoVofy+KRYiq3acxux4NAF4wVAYDVR0gBE0wSzBJBgRVHSAA
# MEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# RG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAS
# BgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQYMBaAFNlBKbAPD2Ns72nX9c0pnqRI
# ajDmMHAGA1UdHwRpMGcwZaBjoGGGX2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2RlJTIwU2ln
# bmluZyUyMFBDQSUyMDIwMjEuY3JsMIGuBggrBgEFBQcBAQSBoTCBnjBtBggrBgEF
# BQcwAoZhaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNy
# b3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAy
# MDIxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0LmNv
# bS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQBFSWDUd08X4g5HzvVfrB1SiV8pk6XP
# HT9jPkCmvU/uvBzmZRAjYk2gKYR3pXoStRJaJ/lhjC5Dq/2R7P1YRZHCDYyK0zvS
# RMdE6YQtgGjmsdhzD0nCS6hVVcgfmNQscPJ1WHxbvG5EQgYQ0ZED1FN0MOPQzWe1
# zbH5Va0dSxtnodBVRjnyDYEm7sNEcvJHTG3eXzAyd00E5KDCsEl4z5O0mvXqwaH2
# PS0200E6P4WqLwgs/NmUu5+Aa8Lw/2En2VkIW7Pkir4Un1jG6+tj/ehuqgFyUPPC
# h6kbnvk48bisi/zPjAVkj7qErr7fSYICCzJ4s4YUNVVHgdoFn2xbW7ZfBT3QA9zf
# hq9u4ExXbrVD5rxXSTFEUg2gzQq9JHxsdHyMfcCKLFQOXODSzcYeLpCd+r6GcoDB
# ToyPdKccjC6mAq6+/hiMDnpvKUIHpyYEzWUeattyKXtMf+QrJeQ+ny5jBL+xqdOO
# PEz3dg7qn8/oprUrUbGLBv9fWm18fWXdAv1PCtLL/acMLtHoyeSVMKQYqDHb3Qm0
# uQ+NQ0YE4kUxSQa+W/cCzYAI32uN0nb9M4Mr1pj4bJZidNkM4JyYqezohILxYkgH
# bboJQISrQWrm5RYdyhKBpptJ9JJn0Z63LjdnzlOUxjlsAbQir2Wmz/OJE703BbHm
# QZRwzPx1vu7S5zCCB54wggWGoAMCAQICEzMAAAAHh6M0o3uljhwAAAAAAAcwDQYJ
# KoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0IElkZW50aXR5IFZlcmlmaWNh
# dGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDIwMB4XDTIxMDQwMTIw
# MDUyMFoXDTM2MDQwMTIwMTUyMFowYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlm
# aWVkIENvZGUgU2lnbmluZyBQQ0EgMjAyMTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBALLwwK8ZiCji3VR6TElsaQhVCbRS/3pK+MHrJSj3Zxd3KU3rlfL3
# qrZilYKJNqztA9OQacr1AwoNcHbKBLbsQAhBnIB34zxf52bDpIO3NJlfIaTE/xrw
# eLoQ71lzCHkD7A4As1Bs076Iu+mA6cQzsYYH/Cbl1icwQ6C65rU4V9NQhNUwgrx9
# rGQ//h890Q8JdjLLw0nV+ayQ2Fbkd242o9kH82RZsH3HEyqjAB5a8+Ae2nPIPc8s
# ZU6ZE7iRrRZywRmrKDp5+TcmJX9MRff241UaOBs4NmHOyke8oU1TYrkxh+YeHgfW
# o5tTgkoSMoayqoDpHOLJs+qG8Tvh8SnifW2Jj3+ii11TS8/FGngEaNAWrbyfNrC6
# 9oKpRQXY9bGH6jn9NEJv9weFxhTwyvx9OJLXmRGbAUXN1U9nf4lXezky6Uh/cgjk
# Vd6CGUAf0K+Jw+GE/5VpIVbcNr9rNE50Sbmy/4RTCEGvOq3GhjITbCa4crCzTTHg
# YYjHs1NbOc6brH+eKpWLtr+bGecy9CrwQyx7S/BfYJ+ozst7+yZtG2wR461uckFu
# 0t+gCwLdN0A6cFtSRtR8bvxVFyWwTtgMMFRuBa3vmUOTnfKLsLefRaQcVTgRnzeL
# zdpt32cdYKp+dhr2ogc+qM6K4CBI5/j4VFyC4QFeUP2YAidLtvpXRRo3AgMBAAGj
# ggI1MIICMTAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0O
# BBYEFNlBKbAPD2Ns72nX9c0pnqRIajDmMFQGA1UdIARNMEswSQYEVR0gADBBMD8G
# CCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3Mv
# UmVwb3NpdG9yeS5odG0wGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDwYDVR0T
# AQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTIftJqhSobyhmYBAcnz1AQT2ioojCBhAYD
# VR0fBH0wezB5oHegdYZzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIw
# Q2VydGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNybDCBwwYIKwYBBQUHAQEE
# gbYwgbMwgYEGCCsGAQUFBzAChnVodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NlcnRzL01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIw
# Um9vdCUyMENlcnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwLQYIKwYB
# BQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20vb2NzcDANBgkqhkiG
# 9w0BAQwFAAOCAgEAfyUqnv7Uq+rdZgrbVyNMul5skONbhls5fccPlmIbzi+OwVdP
# Q4H55v7VOInnmezQEeW4LqK0wja+fBznANbXLB0KrdMCbHQpbLvG6UA/Xv2pfpVI
# E1CRFfNF4XKO8XYEa3oW8oVH+KZHgIQRIwAbyFKQ9iyj4aOWeAzwk+f9E5StNp5T
# 8FG7/VEURIVWArbAzPt9ThVN3w1fAZkF7+YU9kbq1bCR2YD+MtunSQ1Rft6XG7b4
# e0ejRA7mB2IoX5hNh3UEauY0byxNRG+fT2MCEhQl9g2i2fs6VOG19CNep7SquKaB
# jhWmirYyANb0RJSLWjinMLXNOAga10n8i9jqeprzSMU5ODmrMCJE12xS/NWShg/t
# uLjAsKP6SzYZ+1Ry358ZTFcx0FS/mx2vSoU8s8HRvy+rnXqyUJ9HBqS0DErVLjQw
# K8VtsBdekBmdTbQVoCgPCqr+PDPB3xajYnzevs7eidBsM71PINK2BoE2UfMwxCCX
# 3mccFgx6UsQeRSdVVVNSyALQe6PT12418xon2iDGE81OGCreLzDcMAZnrUAx4XQL
# Uz6ZTl65yPUiOh3k7Yww94lDf+8oG2oZmDh5O1Qe38E+M3vhKwmzIeoB1dVLlz4i
# 3IpaDcR+iuGjH2TdaC1ZOmBXiCRKJLj4DT2uhJ04ji+tHD6n58vhavFIrmcxgheP
# MIIXiwIBATBxMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0Mg
# Q0EgMDICEzMAAaNgbzSAO8EvM6AAAAABo2AwDQYJYIZIAWUDBAIBBQCggcwwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwLwYJKoZIhvcNAQkEMSIEICpXe3RS3b2coD0CJveEHlglqtPUYZ2FqSrO
# UfP6C6Y4MGAGCisGAQQBgjcCAQwxUjBQoEqASABCAHUAaQBsAHQAOgAgAFIAZQBs
# AGUAYQBzAGUAXwB2ADMALgAxADQALgAwAGEANQBfADIAMAAyADUAMAAyADEAMQAu
# ADAAM6ECgAAwDQYJKoZIhvcNAQEBBQAEggGAms2TpYvP48W1+NtPVs1iakmvy99q
# MN1aGxZaxMAgi0BDqStmZQUa3mjFzQ0ZcWikQuK71bjMOVmxOxeFg3rFIJb1NEWs
# tr1z+9DPXgRlCdYbOo0bEPXpkJBtZEGUlH25iUYkM2k0vGYVSycYmQsBaBYdDX13
# r/KuJF/hrT8yh6dxKbcf2xaOBbPjfnfveY+UA94pRwKJtv1GgKAxPlojUKc2Ua3x
# ubIQmkl73qFtNO3YNPFgK8M6EBNPd+z3g/Gq9DVQe8hyZII31D81YD21vOpIKmjK
# 5Dqi64fFxnlP9LyJjNmmXNZj6q51wfNmDRWg1+0TFJEKGhy5MU3xwNALRQ7Qb971
# wZv43QJ4gNYOuWCVxFGkd16b98ABjHjrifByak9IN4JNblq3nTvfmbEH6tAvHoGF
# ZdHueI7pDZV0sdJvA7b10r/iNJV9dobAzo6yHP/rYwsPYw18ygNzxG1BYOm4HvMC
# SRbeR3p/UU2t/0ypG/v2Rv9XArhTK+guCs90oYIUoDCCFJwGCisGAQQBgjcDAwEx
# ghSMMIIUiAYJKoZIhvcNAQcCoIIUeTCCFHUCAQMxDzANBglghkgBZQMEAgEFADCC
# AWEGCyqGSIb3DQEJEAEEoIIBUASCAUwwggFIAgEBBgorBgEEAYRZCgMBMDEwDQYJ
# YIZIAWUDBAIBBQAEIAMX8rrzNliA8P/amfoFOph3YicELAfcyJU3B3ZJeMgUAgZn
# m8OExT4YEzIwMjUwMjExMTg0NTI0Ljk1NFowBIACAfSggeCkgd0wgdoxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29m
# dCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkJC
# NzMtOTZGRC03N0VGMTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1l
# IFN0YW1waW5nIEF1dGhvcml0eaCCDyAwggeCMIIFaqADAgECAhMzAAAABeXPD/9m
# LsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jv
# c29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eXM9ETBb1l
# Rkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3TOYtgoBjx
# nG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/Ssah8nWo5
# hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i5F9YciFl
# yAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx69uKqKhTP
# Vi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3GgZwetEKx
# Lms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2HVJo9XxR
# YR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT4I7sDbxO
# mM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnGnsBCd2cj
# RKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914AqHOiEV7xT
# nD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3EQ79PUr8F
# UXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEEAYI3FQEE
# AwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0gBE0wSzBJ
# BgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZ
# BgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1Ud
# IwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJ
# ZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1
# dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYIKwYBBQUH
# MAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9z
# b2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNh
# dGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOCAgEAX4h2
# x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVjJviceW6A
# F6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGEndSpZ5ZM
# 74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1CesufU211rLsl
# LKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3ad4Xtm7yF
# M7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P8tHYIFov
# IP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAodDW8HNtX
# +cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb+H7DRon9
# TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D+mTm8LWV
# ydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN41LGXHeC
# UMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgHAPUvIdto
# SAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeWMIIFfqADAgECAhMzAAAA
# Rd975+cMCRaeAAAAAABFMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29m
# dCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEyNjE4NDg0
# N1oXDTI1MTExOTE4NDg0N1owgdoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMx
# JjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkJCNzMtOTZGRC03N0VGMTUwMwYDVQQD
# EyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMCO0/Q3QmA1J2H4+L2vjJPb
# XT5sdt3C8JRxyAPGRCLkxIKxVfBeYCABw874Hay6WgHzWLecvlbaceUR2xVSZ0YJ
# 8FhNxawyhjta/pBV3F0Qsc2o2+67+5/qQUsIcMCpkHokwPFGTbo6LC0NVtKIzhC+
# 8THOJeZsy7oAOgi+tfMC+4GmVsGjhqukUTgu2L9a9fPstTtpkqBDMzN5Va9z7yI9
# 1E5rW6L0XmTnOzZT7hj0wMI17aqUtehlOw3+AqwbwvWuZ/TNeaKgrVo2RGZbIHzM
# wNvCr0iqqkv1MkQVMGyxAtJD+nf6zs8stLsQoD9ufZ7c1BenPje15guV9ODxaOzk
# pynLCdNOI/VuIJIujLURwZT1tYQdxFJT8zH8e7z1ZPv9Hq4dwynuVFImeeGguoXJ
# ZN6nO+DqEXF5EYqoXhO3wyzJpBsxs4jH4ovKNStH3A1IS9RLX39hi+htDd6rP9rL
# Sa7ZuKMqFESWsJUzecifOc83BdV0mjOz+feY4Rc/IAeEAU77Ou8EGuZ6zCURzVk5
# b6mGyJqGGF+8oc5gFCxTt3rLJ67yK4hqYtab+Db6D0rL4KEO9A41VKw24n/IMDpS
# Hn6XLp2xmMwijWQt6znsVOiRnlNDZWSwPVD2hd6cXp4xBarGVla9ySn+v7G7LQCB
# bMjNmTjIr5SPKX2lkuFvAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQUJdDb6vUl0ETJ
# p/Adxq89h2MrlfIwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk92yEwbAYD
# VR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0El
# MjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwUHVibGlj
# JTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNVHRMBAf8E
# AjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDBmBgNV
# HSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wCAYGZ4EM
# AQQCMA0GCSqGSIb3DQEBDAUAA4ICAQBsvbXnWngk+LHhRxiyoELXkYj8tLcDbaC6
# jlPNIFms6ItC+Qx0BoV4lQzFSW/c7tSFNyebpzccGnfYQOv+I3rv5B4GRc9xBLM3
# M0+PNJ88Mevc1rVT7gh//2+4dajWdKe2CqWplA7tWYwVrkpoD4SvxoFS1yztU0Op
# 7a428/GzCX9+R7FBVrwka2z6V+IYTXqVGy9I1N5dWBAh6JXg4ba56leb/q8/5V0M
# YRslUoz4fjU4PNF8JPDn/+7GmJ7zHVtvMaHpVCyGJxak8T5/tbyiV9UJ5R8wQVLV
# ilQz1P3zBEXFNlBdOdnIYp9EwkGsj/HAAXdY2GCC0DGrYmCc0iwAHTYjzMf3JaaA
# 9MNd3oKTA/Qd28dKsq7s9jECt9SkeGcKChi3wsLrmsswdmhA3Kd0PklRoJ4GJ/Em
# k453lGS6IYf1pPQOCzpGYQwWIxUNQaLW03PSmFFdOSVzWoXjEsEYhULgnmZ07asI
# TflKUzvpWRswY8T2E1zm0GK2Or7AeI85oM1dvlJBOidp3MyT+i3Yoxq9jyj6UN21
# RvHaapzmmPGoSrUKLqE3yTxxtuQa619sIT3IfMWQWElp9DWI/8mSo3v3K6iWL1KB
# AC4aJkG7gVOfhb+FP0fMczFBiYKHhyIfJ/TqDTdiRLTDnsqSOqE6xlUbSmLR8mZm
# +GuYFDPE1zGCA9QwggPQAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBS
# U0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABF33vn5wwJFp4AAAAAAEUwDQYJ
# YIZIAWUDBAIBBQCgggEtMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkq
# hkiG9w0BCQQxIgQggo22eYFTXYGyXh2zFLnVDTWERThWxuvXnt0vTkvb/REwgd0G
# CyqGSIb3DQEJEAIvMYHNMIHKMIHHMIGgBCC4BFU6yMiKP3HjL+a4TxzO9IjPRdLr
# ykEVDn4h39JucTB8MGWkYzBhMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVibGljIFJTQSBU
# aW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEXfe+fnDAkWngAAAAAARTAiBCAAkrzg
# 6cjtr53BKdBK9xhHRKR9x7gomwz8hmsLEpdhCjANBgkqhkiG9w0BAQsFAASCAgCV
# K/ACRz5c88RBT4rUvB1WPFMqI1xUB2IzqjtL0ZQ5AUb0JAxGKtATxURVdmlJCab0
# 3wFhz3XHO8c6dLSkZ3NYZA6EDmdWMmgL8ipUmIGMGRzcjwFACrQVHZFKUu2ic7QN
# Gk61J64GojHiYhRp9VnUY2kQu+vIk7wULbRe8bCYXLJ4B/okpVBPrl0I6RmWkMkD
# YRUntTPTDs55BStG9RQhfz32Ds79h2VQeiTVApiu/TvSa51kIAE1fThUVGT+rvVh
# 8RFa/FYYFeM6C+QxoeJqGnoTCOEUXLbsqZ6xqqhIlqTuBgPcRXmaY3u2febCisr0
# /1GtL5GLeqDdvRjGQWX5SrRUxaWnu6HO9ffJ/AAXSlZ/d/aa+Y9zXx2WKhKYtcuS
# ER68PsNkh9Xv9bvIC+cA/NWq3/1xchPWQKA9emc1gD7AkVOR6Y7gYx3qWE2vuETV
# udXMeS18aGDNyqOsHxjN4xqFfHnaiotbBvti2Z6dOYr8uxUfAoWluNyxgJfWghcE
# nGhiED42+I/N1nNk3TjA+Ax+51IyD57sp4Dty/CSVhDKcko0MTOWvC888v+qYWFr
# 7zjdXKhDMiKh3D6TErMr3zdZKqTndC+ESiNsSE/K953vOIbXGw6dIheQPkLYxprA
# 4Kd56CkgSKYQGm5G+edD4bL9cGzAMthavmuF9NAoqA==
# SIG # End signature block
