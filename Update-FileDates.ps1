<#
    Get one Metadata Property from the File ($dateProperty) and replace two Timestamps with that:
    - CreationTime
    - LastWriteTime

    Use: .\Update-FileDates <Folder-Path>
#>

$dateProperty = 'Aufnahmedatum'
$DateTimeFormat = "dd.MM.yyyy HH:mm"

function Get-FileMetaData {
    <#
    .SYNOPSIS
    Small function that gets metadata information from file providing similar output to what Explorer shows when viewing file
    .DESCRIPTION
    Small function that gets metadata information from file providing similar output to what Explorer shows when viewing file
    .PARAMETER File
    FileName or FileObject
    .EXAMPLE
    Get-ChildItem -Path $Env:USERPROFILE\Desktop -Force | Get-FileMetaData | Out-HtmlView -ScrollX -Filtering -AllProperties
    .EXAMPLE
    Get-ChildItem -Path $Env:USERPROFILE\Desktop -Force | Where-Object { $_.Attributes -like '*Hidden*' } | Get-FileMetaData | Out-HtmlView -ScrollX -Filtering -AllProperties
    .NOTES
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)][Object] $File,
        [switch] $Signature
    )
    Process {
        foreach ($F in $File) {
            $MetaDataObject = [ordered] @{}
            if ($F -is [string]) {
                $FileInformation = Get-ItemProperty -Path $F
            } elseif ($F -is [System.IO.DirectoryInfo]) {
                #Write-Warning "Get-FileMetaData - Directories are not supported. Skipping $F."
                continue
            } elseif ($F -is [System.IO.FileInfo]) {
                $FileInformation = $F
            } else {
                Write-Warning "Get-FileMetaData - Only files are supported. Skipping $F."
                continue
            }
            $ShellApplication = New-Object -ComObject Shell.Application
            $ShellFolder = $ShellApplication.Namespace($FileInformation.Directory.FullName)
            $ShellFile = $ShellFolder.ParseName($FileInformation.Name)
            $MetaDataProperties = [ordered] @{}
            0..400 | ForEach-Object -Process {
                $DataValue = $ShellFolder.GetDetailsOf($null, $_)
                $PropertyValue = (Get-Culture).TextInfo.ToTitleCase($DataValue.Trim()).Replace(' ', '')
                if ($PropertyValue -eq $DateProperty) {
                    $MetaDataProperties["$_"] = $PropertyValue
                }
            }
            foreach ($Key in $MetaDataProperties.Keys) {
                $Property = $MetaDataProperties[$Key]
                $Value = $ShellFolder.GetDetailsOf($ShellFile, [int] $Key)

                $MetaDataObject["$Property"] = $Value

            }
            if ($FileInformation.VersionInfo) {
                $SplitInfo = ([string] $FileInformation.VersionInfo).Split([char]13)
                foreach ($Item in $SplitInfo) {
                    $Property = $Item.Split(":").Trim()
                    if ($Property[0] -and $Property[1] -ne '') {
                        $MetaDataObject["$($Property[0])"] = $Property[1]
                    }
                }
            }
            $MetaDataObject["Attributes"] = $FileInformation.Attributes
            $MetaDataObject['IsReadOnly'] = $FileInformation.IsReadOnly
            $MetaDataObject['IsHidden'] = $FileInformation.Attributes -like '*Hidden*'
            $MetaDataObject['IsSystem'] = $FileInformation.Attributes -like '*System*'
            if ($Signature) {
                $DigitalSignature = Get-AuthenticodeSignature -FilePath $FileInformation.Fullname
                $MetaDataObject['SignatureCertificateSubject'] = $DigitalSignature.SignerCertificate.Subject
                $MetaDataObject['SignatureCertificateIssuer'] = $DigitalSignature.SignerCertificate.Issuer
                $MetaDataObject['SignatureCertificateSerialNumber'] = $DigitalSignature.SignerCertificate.SerialNumber
                $MetaDataObject['SignatureCertificateNotBefore'] = $DigitalSignature.SignerCertificate.NotBefore
                $MetaDataObject['SignatureCertificateNotAfter'] = $DigitalSignature.SignerCertificate.NotAfter
                $MetaDataObject['SignatureCertificateThumbprint'] = $DigitalSignature.SignerCertificate.Thumbprint
                $MetaDataObject['SignatureStatus'] = $DigitalSignature.Status
                $MetaDataObject['IsOSBinary'] = $DigitalSignature.IsOSBinary
            }
            [PSCustomObject] $MetaDataObject
        }
    }
}

Function Update-FileDates {
    Process {
        $path = $_.DirectoryName + '\' + $_.Name
        $fileMetaData = $_ | Get-FileMetaData
        # --> Remove ANYTHING BUT digits (0-9), dots, colons or Spaces from the DateTime-String. Add more Characters to Regex if needed
        $dateStringToParse = $fileMetaData.Aufnahmedatum -replace '[^0-9.: ]'
        $aufnahmeDatum = [dateTime]::ParseExact($dateStringToParse, $DateTimeFormat, $null)
        Set-ItemProperty -Path $path -Name LastWriteTime -Value $aufnahmeDatum
        Set-ItemProperty -Path $path -Name CreationTime -Value $aufnahmeDatum
        Write-Host $_.Name + ", Aufnahmedatum: " + $aufnahmeDatum 
    }
}

Get-ChildItem -Path $args[0] | Update-FileDates
