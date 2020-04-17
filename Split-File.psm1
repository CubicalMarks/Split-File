<#
.SYNOPSIS
    PowerShell module to split one or many input files into smaller files with specified line count.
.DESCRIPTION
    
.EXAMPLE
    PS C:\> Split-File foo.txt -Split 100 -Header 2 -AddHeaders
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Split-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName = $true,
                   HelpMessage="Path to one or more files.")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]
        $Path,
        [Parameter(Mandatory=$true,
                   HelpMessage="Number of lines to split input file on")]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Split,
        [Parameter(Mandatory=$false,
                   HelpMessage="Number of header rows in input file (defaults to 1)")]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Header = 1,
        [Parameter(Mandatory=$false,
                   HelpMessage="Add header from original file to resulting files (default to false")]
        [switch]
        $AddHeaders
    )
    
    begin {
        if (Test-Path -PathType Leaf -Path $Path) {
            $files = Get-ChildItem -File $Path
        } else {
            Write-Error "Invalid path"
            exit 1
        }
    }
    
    process {
        $Processed = 0
        foreach ($file in $files) {
            $ProgressActivity = "Splitting $($file.Name):"
            Write-Host "Splitting $($file.Name)"
            Write-Progress -Activity $ProgressActivity `
                -Status "Calculaing total number of output files" `
                -PercentComplete 0
            
            try {
                $FileReader = New-Object System.IO.StreamReader $file
            } catch {
                Write-Error "Error: Could not open $($file.FullName)"
                break
            }
            
            $TotalLines     = -$Header + $((Get-Content $file -ReadCount 1000 | ForEach-Object {$x += $_.Count });$x)
            $TotalBatches   = [Math]::Ceiling($TotalLines / $Split)
            $FileHeader     = [System.Collections.ArrayList]@()
            
            $Counter        = 0
            while ($Counter -lt $Header) {
                if (($Counter % ($Header / 20)) -eq 0 -or $Counter -eq 0) {
                    Write-Progress -Activity $ProgressActivity `
                        -Status "Reading header" `
                        -PercentComplete ([Math]::Ceiling($Counter / $Header * 100))
                }
                
                $null = $FileHeader.Add($FileReader.ReadLine())
                $Counter++
            }
            
            $Batch = 1
            while ($FileReader.EndOfStream -ne $true) {
                $ExportDir = $file | Split-Path -Parent
                $ExportFile = $file.BaseName + "_" `
                + $Batch.ToString().PadLeft($TotalBatches.ToString().Length, '0') `
                + $file.Extension
                
                Write-Host "-> $ExportFile"
                Write-Progress -Activity $ProgressActivity `
                    -Status "Writing $ExportFile (of $TotalBatches)" `
                    -PercentComplete ([Math]::Ceiling($Batch / $TotalBatches * 100))
                
                try {
                    $FileWriter = New-Object System.IO.StreamWriter `
                        -ArgumentList $(Join-Path -Path $ExportDir -ChildPath $ExportFile)
                } catch {
                    Write-Error "Error: Could not write file: $ExportFile"
                    break
                }
                
                if ($AddHeaders) {
                    foreach ($line in $FileHeader) {
                        $FileWriter.WriteLine($line)
                    }
                }
                
                $Counter = 0
                while ($Counter -lt $Split -and $FileReader.EndOfStream -ne $true) {
                    $FileWriter.WriteLine($FileReader.ReadLine())
                    $Counter++
                }

                $FileWriter.Close()
                $Batch++

            }
            
            $FileReader.Close()
            $Processed++
        }
    }
    
    end {
        $FileReader.Close()
        $FileWriter.Close()

        Write-Host "`n$Processed file(s) processed`n"
    }
}
