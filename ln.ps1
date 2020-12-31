$version = '1.0.0'
$usage = "Usage: ln [OPTION]... [-T] TARGET LINK_NAME   (1st form)
  or:  ln [OPTION]... TARGET                  (2nd form)
  or:  ln [OPTION]... TARGET... DIRECTORY     (3rd form)
  or:  ln [OPTION]... -t DIRECTORY TARGET...  (4th form)

In the 1st form, create a link to TARGET with the name LINK_NAME.
In the 2nd form, create a link to TARGET in the current directory.
In the 3rd and 4th forms, create links to each TARGET in DIRECTORY.

Create hard links by default, symbolic links with --symbolic.
By default, each destination (name of new link) should not already exist.
When creating hard links, each TARGET must exist.  Symbolic links
can hold arbitrary text; if later resolved, a relative link is
interpreted in relation to its parent directory.

Mandatory arguments to long options are mandatory for short options too.
      --backup[=CONTROL]      make a backup of each existing destination file
  -b                          like --backup but does not accept an argument
  -d, -F, --directory         allow the superuser to attempt to hard link
                                directories (note: will probably fail due to
                                system restrictions, even for the superuser)
  -f, --force                 remove existing destination files
  -i, --interactive           prompt whether to remove destinations
  -L, --logical               dereference TARGETs that are symbolic links
  -n, --no-dereference        treat LINK_NAME as a normal file if
                                it is a symbolic link to a directory
  -P, --physical              make hard links directly to symbolic links
  -r, --relative              create symbolic links relative to link location
  -s, --symbolic              make symbolic links instead of hard links
  -S, --suffix=SUFFIX         override the usual backup suffix
  -t, --target-directory=DIRECTORY  specify the DIRECTORY in which to create
                                the links
  -T, --no-target-directory   treat LINK_NAME as a normal file always
  -v, --verbose               print name of each linked file
      --help     display this help and exit
      --version  output version information and exit

The backup suffix is '~', unless set with --suffix or SIMPLE_BACKUP_SUFFIX.
The version control method may be selected via the --backup option or through
the VERSION_CONTROL environment variable.  Here are the values:

  none, off       never make backups (even if --backup is given)
  numbered, t     make numbered backups
  existing, nil   numbered if numbered backups exist, simple otherwise
  simple, never   always make simple backups

Using -s ignores -L and -P.  Otherwise, the last option specified controls
behavior when a TARGET is a symbolic link, defaulting to -P.

GNU coreutils online help: <http://www.gnu.org/software/coreutils/>
Full documentation at: <http://www.gnu.org/software/coreutils/ln>
Github: https://github.com/moeshin/ln.ps1"

$files = @()
$force = $false
$interactive= $false
$relative = $false
$symbolic = $false
$verbose = $false
$form = 0

function isAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = new-object System.Security.Principal.WindowsPrincipal $id
    $p.isinrole([security.principal.windowsbuiltinrole]::administrator)
}

$isAdmin = isAdmin

function sudoCmd {
    if ($isAdmin) {
        cmd /c $args
    } else {
        sudo cmd /c $args
    }
}

function isExist($file) {
    return Test-Path $file
}

function isDir($file) {
    return Test-Path $file -PathType Container
}

function isTargetDir($file) {
    return $file.EndsWith('\') -or (isDir $file)
}

function getBasename($path) {
    if ($path.EndsWith('\')) {
        return [System.IO.Path]::GetDirectoryName($path)
    } else {
        return [System.IO.Path]::GetFileName($path)
    }
}

function getDirName($path) {
    return [System.IO.Path]::getBasename($path)
}

function pathToDos($path) {
    return $path.Replace('/', '\')
}

function mklink($options, $link, $target) {
    sudoCmd mklink $options $link $target
    return $?
}

function testParams($target, $dest) {
    if (!$symbolic -and (isTargetDir $target)) {
        Write-Host "ln: ${dest}: hard link not allowed for directory"
        return $false
    }
    if (isExist $dest) {
        if ($force) {
            (Get-Item $dest).Delete()
            return $true
        } elseif ($interactive) {
            Write-Host -NoNewline "ln: replace '$dest'? "
            if ((Read-Host).StartsWith('y', $true, $null)) {
                Remove-Item $dest
            } else {
                return $false
            }
        }
        Write-Host "ln: failed to create $linkType link '$dest': File exists"
        return $false
    }
    $parent = [System.IO.Path]::GetDirectoryName($dest)
    if (![String]::IsNullOrEmpty($parent) -and !(isDir $parent)) {
        Write-Host "ln: failed to create $linkType link '$dest': No such file or directory"
        return $false
    }
    return $true
}

function getAbsolutePath($path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
}

function splitPath($path) {
    return $path.split('\', [StringSplitOptions]::RemoveEmptyEntries)
}

function getRelativePath($dir, $target) {
    $dir = pathToDos $dir
    $target = pathToDos $target
    $dir = getAbsolutePath $dir
    $target = getAbsolutePath $target
    $a1 = splitPath $dir
    $a2 = splitPath $target

    $len1 = $a1.Count
    $len2 = $a2.Count
    $len = if ($len1 -lt $len2) {$len1} else {$len2}

    $path = ''
    for ($i = 0; $i -lt $len; ++$i) {
        if ($a1[$i] -ne $a2[$i]) {
            if ($i -eq 0) {
                # Cannot find relative path on different disk
                return $target
            }
            $n = $len1 - $i - 1
            if ($n -eq 0) {
                $path += '.\'
            } elseif ($n -gt 0)  {
                $path += '..\' * $n
            }
            $path += $a2[$i..$len2] -join '\'

            return $path
        }
    }
}

function lnToDir($target, $dir) {
    $target = pathToDos $target
    $dir = pathToDos $dir
    $basename = getBasename $target
    $dest = Join-Path $dir $basename
    if (testParams $target $dest) {
        if (isTargetDir $target) {
            $options += '/D'
        }
        if (mklink $options $dest $target) {
            if ($verbose) {
                Write-Host "'$dest' $linkMark '$target'"
            }
        }
    }
}

function foreachArgs($arg) {
    switch -CaseSensitive ($arg) {
        '--help' {
            Write-Host $usage
            exit
        }
        '--version' {
            Write-Host $version
            exit
        }
        {$_ -ceq '-d' -or $_ -ceq '-F' -or $_ -ceq '--directory'} {
            "ln: hard link not allowed for directory in Winodws"
            exit
        }
        {$_ -ceq '-s' -or $_ -ceq '--symbolic'} {
            $script:symbolic = $true
            break
        }
        {$_ -ceq '-f' -or $_ -ceq '--force'} {
            $script:force = $true
            break
        }
        {$_ -ceq '-i' -or $_ -ceq '--interactive'} {
            $script:interactive = $true
            break
        }
        {$_ -ceq '-r' -or $_ -ceq '--relative'} {
            $script:relative = $true
            break
        }
        {$_ -ceq '-t' -or $_ -ceq '--target-directory'} {
            $script:form = 1
            break
        }
        {$_ -ceq '-T' -or $_ -ceq '--no-target-directory'} {
            $script:form = 4
            break
        }
        {$_ -ceq '-v' -or $_ -ceq '--verbose'} {
            $script:verbose = $true
            break
        }
        default {
            $_args = $_.Substring(1);
            if (!$_args.StartsWith('-')) {
                $len = $_args.Length
                for($i=1; $i -le $len; $i++)
                {
                    echo foreachArgs "-$_arg"
                }
            }
            Write-Host "ln: invalid option -- '$_'"
            Write-Host "Try 'ln --help' for more information."
            exit 1
        }
    }
}

foreach ($arg in $args) {
    if (!$arg.StartsWith('-')) {
        $files += $arg
        continue
    }
    foreachArgs $arg
}

$len = $files.Count
if ($symbolic) {
    $linkType = 'symbolic'
    $linkMark = '->'
    $options = ''
} else {
    $linkType = 'hard'
    $linkMark = '=>'
    $options = '/H'
}

switch ($len) {
    0 {
        Write-Host "ln: missing file operand"
        Write-Host "Try 'ln --help' for more information."
        exit 1
    }
    1 {
        $form = 2
        break
    }
    2 {
        if ($form -eq 0) {
            $form = if (isDir $files[1]) {3} else {1}
        }
        break
    }
    default {
        if ($form -eq 0) {
            $form = 3
        }
    }
}

switch ($form) {
    1 {
        $target = pathToDos $files[0]
        $dest = pathToDos $files[1]
        if (testParams $target $dest) {
            if (isTargetDir $target) {
                $options += '/D'
            }
            if (mklink $options $dest $target) {
                if ($verbose) {
                    Write-Host "'$dest' $linkMark '$target'"
                }
            }
        }
        break
    }
    2 {
        lnToDir $files[0] .
        break
    }
    3 {
        
        lnToDir $files[0] $files[1]
        break
    }
}

#"Files:"
#$files
