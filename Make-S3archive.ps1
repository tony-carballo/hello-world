<# 

.SYNOPSIS
    Creates file/folder archive and MD5 hash, then uploads to S3 bucket.
.DESCRIPTION
    This script creates an archive of a given directory, formats the name  
    to <name>-latest.zip, then creates an MD5 hash of the file. Then
    checks if file name previously exists in the S3 bucket and if so renames 
    to <name>-<date>.zip. Finally, the two files are uploaded to the selected S3 bucket.
.NOTES
    File Name      : Make-S3archive.ps1
    Author         : Tony Carballo 
    Prerequisite   : Requires - PowerShell 5.x or higher, AWS Tools for Windows installed,
                     credentials to the S3 Bucket.
    Copyright 2016 - Tony Carballo
.LINK
    Script posted over: GitHub
    https://github.com/tony-carballo/hello-world/Make-S3Archive.ps1
.EXAMPLE
    <PATH>\Make-S3archive.ps1 -folder2bak <path to folder> -s3bucket <bucket name> -appName <name for archive>

#>

# Create mandatory parameters for script and validate path and bucket name
Param(
  [Parameter(Mandatory=$True,Position=1)]
  [ValidateScript({Test-Path -Path $_})]
  [String]$folder2bak,

  [Parameter(Mandatory=$True,Position=2)]
  [ValidateScript({Test-S3Bucket -BucketName $_})]
  [String]$s3bucket,

  [Parameter(Mandatory=$True)]
  [String]$appName
  )

Import-Module AWSPowerShell
$Date = Get-Date -Format yyyy-MM-dd-hh
$workingDir = "C:\Windows\temp"

# Ensure the folder to backup is not the working directory, attempt to catch any errors
if ($folder2bak -eq $workingDir){
  Throw "$folder2bak cannot be compressed. Choose another directory."
  }
if($appName -eq $null){
  Throw "$appName cannot be null."
  }
try{
  Compress-Archive -Path $folder2bak -DestinationPath $workingDir\$appName-latest.zip -Force -ErrorAction Stop
  }
catch{
  Write-Error -Message "Archive could not be compressed."   
  }

try{
  Get-FileHash -Path $workingDir\$appName-latest.zip -Algorithm MD5 >> $workingDir\$appName-$date.sig -ErrorAction Stop
  }
catch{
  Write-Error -Message "File hash could not be created."
  }

# Find out if the S3 object exists 
$testArchive = Get-S3Object -BucketName $s3bucket -Key $appName-latest.zip
# If the S3 object does not exist don't try copy
if($testArchive -ne $null){
  Copy-S3Object -BucketName $s3bucket -Key $appName-latest.zip -DestinationKey $appName-$date.zip
  }
try{
# Write the two files to S3 with the formatted naming
  Write-S3Object -BucketName $s3bucket -file $workingDir\$appName-latest.zip
  Write-S3Object -BucketName $s3bucket -file $workingDir\$appName-$date.sig
  }
catch{
  Write-Error -Message "Archive or MD5 Hash could not be written."
  }

# Clean up C:\Windows\temp
try{
  Get-ChildItem $workingDir\* -Include $appName-latest.zip | Remove-item 
  Get-ChildItem $workingDir\* -Include $appName-*.sig | Remove-Item   
  }
catch{
  Write-Error -Message "Could not delete items from C:\Windows\temp."
  }
