use sha2::{Digest, Sha256};
use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{self, Read, Write},
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

const PAYLOAD: &[u8] = include_bytes!(env!("PATCH_PAYLOAD"));
const ORIGINAL_SHA: &str = env!("OFFICIAL_SHA256");
const BUILD_TAG: &str = env!("PATCHER_BUILD_TAG");
const API: &str = "https://api.github.com/repos/NikitaRTN/Horizon-Patcher/releases/latest";
const ASSET_PREFIX: &str = "https://github.com/NikitaRTN/Horizon-Patcher/releases/download/";

fn hash_bytes(data: &[u8]) -> String {
    format!("{:x}", Sha256::digest(data))
}
fn hash_file(path: &Path) -> Result<String, String> {
    let mut f = File::open(path).map_err(|e| e.to_string())?;
    let mut h = Sha256::new();
    let mut buf = [0u8; 65536];
    loop {
        let n = f.read(&mut buf).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        h.update(&buf[..n]);
    }
    Ok(format!("{:x}", h.finalize()))
}
fn eligible(actual: &str, original: &str, previous: Option<&str>) -> bool {
    actual.eq_ignore_ascii_case(original)
        || previous.is_some_and(|s| actual.eq_ignore_ascii_case(s))
}
fn canonical(path: &Path) -> Result<PathBuf, String> {
    let m = fs::symlink_metadata(path).map_err(|e| e.to_string())?;
    if !m.is_file() || m.file_type().is_symlink() {
        return Err("Target must be a regular file, not a symlink".into());
    }
    path.canonicalize().map_err(|e| e.to_string())
}
fn state_dir(target: &Path) -> Result<PathBuf, String> {
    let base = env::var_os("LOCALAPPDATA").ok_or("LOCALAPPDATA not set")?;
    let id = hash_bytes(target.to_string_lossy().to_lowercase().as_bytes());
    Ok(PathBuf::from(base)
        .join("HorizonPrivacyPatcher")
        .join(&id[..24]))
}
fn state(target: &Path) -> Option<serde_json::Value> {
    let d = state_dir(target).ok()?;
    let v: serde_json::Value =
        serde_json::from_slice(&fs::read(d.join("state.json")).ok()?).ok()?;
    if v.get("target")?.as_str()? != target.to_string_lossy() {
        return None;
    }
    Some(v)
}
fn ps(script: &str, vars: &[(&str, &str)]) -> Result<std::process::Output, String> {
    let mut c = Command::new("powershell.exe");
    c.args([
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-STA",
        "-Command",
        script,
    ]);
    for (k, v) in vars {
        c.env(k, v);
    }
    c.output().map_err(|e| e.to_string())
}
fn plain_windows_path(path: &Path) -> String {
    let s = path.to_string_lossy();
    if let Some(rest) = s.strip_prefix(r"\\?\UNC\") {
        format!(r"\\{rest}")
    } else if let Some(rest) = s.strip_prefix(r"\\?\") {
        rest.to_owned()
    } else {
        s.into_owned()
    }
}
fn is_not_running(target: &Path) -> Result<(), String> {
    let t = plain_windows_path(target);
    let script = r#"$ErrorActionPreference='Stop'; $target=$env:PATCH_TARGET; $name=[IO.Path]::GetFileNameWithoutExtension($target); foreach($p in @(Get-Process -Name $name -ErrorAction SilentlyContinue)){try {$path=$p.Path; if (-not $path -or [string]::Equals([IO.Path]::GetFullPath($path),[IO.Path]::GetFullPath($target),[StringComparison]::OrdinalIgnoreCase)){exit 2}} catch {exit 3}}; exit 0"#;
    let out = ps(script, &[("PATCH_TARGET", &t)])?;
    if !out.status.success() {
        return Err(
            "Close the selected launcher first (or process status could not be checked)".into(),
        );
    }
    Ok(())
}
struct ApplyLock(PathBuf);
impl Drop for ApplyLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.0);
    }
}
fn apply(target: &Path) -> Result<(), String> {
    let target = canonical(target)?;
    let lock_dir = state_dir(&target)?;
    fs::create_dir_all(&lock_dir).map_err(|e| e.to_string())?;
    let lock_path = lock_dir.join("apply.lock");
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&lock_path)
        .map_err(|_| "Another patch may be running or a stale apply.lock needs inspection")?;
    let _lock = ApplyLock(lock_path);
    let prior = state(&target);
    let old = hash_file(&target)?;
    let new = hash_bytes(PAYLOAD);
    if old == new {
        let mut record = prior.ok_or("This file already matches the payload, but has no patch state; refusing to register auto-update")?;
        if record["installed_sha256"].as_str() != Some(new.as_str()) {
            return Err("Patch state does not match the installed file".into());
        }
        record["build_tag"] = serde_json::Value::String(BUILD_TAG.to_string());
        let tmp = lock_dir.join(format!("state-existing-{}.new", std::process::id()));
        fs::write(
            &tmp,
            serde_json::to_vec_pretty(&record).map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
        let saved = lock_dir.join("state.json");
        fs::remove_file(&saved).map_err(|e| e.to_string())?;
        fs::rename(&tmp, &saved).map_err(|e| e.to_string())?;
        println!("Already patched: {}", target.display());
        return Ok(());
    }
    let prior_sha = prior
        .as_ref()
        .and_then(|s| s.get("installed_sha256"))
        .and_then(|s| s.as_str());
    if !eligible(&old, ORIGINAL_SHA, prior_sha) {
        return Err(format!(
            "Unsupported or modified launcher (SHA-256 {old}). Nothing changed."
        ));
    }
    is_not_running(&target)?;
    let parent = target.parent().ok_or("Target has no parent")?;
    let unique = format!(
        "{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_nanos()
    );
    let temporary = parent.join(format!(".horizon-patcher-{unique}.tmp"));
    let backup = parent.join(format!("horizon-launcher-{unique}.backup"));
    let mut f = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temporary)
        .map_err(|e| e.to_string())?;
    if let Err(e) = f.write_all(PAYLOAD).and_then(|_| f.sync_all()) {
        let _ = fs::remove_file(&temporary);
        return Err(e.to_string());
    }
    drop(f);
    if hash_file(&target)? != old {
        let _ = fs::remove_file(&temporary);
        return Err("Launcher changed during patching; no replacement made".into());
    }
    if let Err(e) = fs::rename(&target, &backup) {
        let _ = fs::remove_file(&temporary);
        return Err(format!("Cannot make backup: {e}"));
    }
    if let Err(e) = fs::rename(&temporary, &target) {
        let restore = fs::rename(&backup, &target);
        let _ = fs::remove_file(&temporary);
        return Err(format!(
            "Could not install: {e}; restore: {restore:?}. Backup: {}",
            backup.display()
        ));
    }
    let d = state_dir(&target)?;
    fs::create_dir_all(&d).map_err(|e| e.to_string())?;
    let record = serde_json::json!({"target":target.to_string_lossy(),"installed_sha256":new,"build_tag":BUILD_TAG,"backup":backup.to_string_lossy()});
    let temp_state = d.join(format!("state-{unique}.new"));
    fs::write(
        &temp_state,
        serde_json::to_vec_pretty(&record).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    let state = d.join("state.json");
    if state.exists() {
        fs::remove_file(&state).map_err(|e| e.to_string())?
    }
    fs::rename(temp_state, state).map_err(|e| e.to_string())?;
    println!("Patched {}\nBackup: {}", target.display(), backup.display());
    Ok(())
}
fn scan_dir(
    dir: &Path,
    depth: u8,
    out: &mut Vec<PathBuf>,
    budget: &mut usize,
    deadline: std::time::Instant,
) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten().take(1000) {
        if *budget == 0 || std::time::Instant::now() >= deadline {
            break;
        }
        *budget -= 1;
        let Ok(ty) = entry.file_type() else { continue };
        if ty.is_symlink() {
            continue;
        }
        let p = entry.path();
        if ty.is_file()
            && entry
                .file_name()
                .to_string_lossy()
                .eq_ignore_ascii_case("horizon-launcher.exe")
        {
            if let Ok(p) = canonical(&p) {
                if !out.contains(&p) {
                    out.push(p)
                }
            }
        } else if depth > 0 && ty.is_dir() {
            scan_dir(&p, depth - 1, out, budget, deadline)
        }
    }
}
fn candidates() -> Vec<PathBuf> {
    let mut out = Vec::new();
    let mut budget = 15000;
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
    for (key, tail, depth) in [
        ("USERPROFILE", "Desktop", 1),
        ("OneDrive", "Desktop", 1),
        ("USERPROFILE", "Downloads", 1),
        ("LOCALAPPDATA", "Programs", 2),
        ("APPDATA", "horizon-launcher", 1),
    ] {
        if let Some(base) = env::var_os(key) {
            scan_dir(
                &PathBuf::from(base).join(tail),
                depth,
                &mut out,
                &mut budget,
                deadline,
            )
        }
    }
    out
}
fn manual() -> Result<PathBuf, String> {
    let script = r#"Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Title='Select Horizon launcher'; $d.Filter='Executable (*.exe)|*.exe|All files (*.*)|*.*'; [Console]::OutputEncoding=New-Object System.Text.UTF8Encoding; if($d.ShowDialog() -eq 'OK'){[Console]::Write($d.FileName)} else {exit 1}"#;
    let out = ps(script, &[])?;
    if !out.status.success() {
        return Err("No file selected".into());
    }
    let s = String::from_utf8(out.stdout).map_err(|e| e.to_string())?;
    Ok(PathBuf::from(s.trim()))
}
fn choose() -> Result<PathBuf, String> {
    let list = candidates();
    println!("Detected Horizon launchers:");
    for (i, p) in list.iter().enumerate() {
        println!("  {}. {}", i + 1, p.display())
    }
    println!("Enter a number, or M to choose a file manually:");
    let mut s = String::new();
    io::stdin().read_line(&mut s).map_err(|e| e.to_string())?;
    if s.trim().eq_ignore_ascii_case("m") {
        return manual();
    };
    let n: usize = s.trim().parse().map_err(|_| "Invalid choice")?;
    list.get(n.wrapping_sub(1))
        .cloned()
        .ok_or("Invalid choice".into())
}
fn install_task(target: &Path) -> Result<(), String> {
    let target = canonical(target)?;
    let dir = state_dir(&target)?;
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let exe = dir.join("updater.exe");
    if !exe.exists() {
        fs::copy(env::current_exe().map_err(|e| e.to_string())?, &exe)
            .map_err(|e| e.to_string())?;
    }
    let id = dir
        .file_name()
        .ok_or("Invalid task path")?
        .to_string_lossy();
    let name = format!("HorizonPrivacyPatcher-{id}");
    let action = format!(
        "\"{}\" --watch \"{}\"",
        plain_windows_path(&exe),
        plain_windows_path(&target)
    );
    let query = Command::new("schtasks.exe")
        .args(["/Query", "/TN", &name])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|e| e.to_string())?;
    if query.success() {
        return Ok(());
    }
    let r = Command::new("schtasks.exe")
        .args([
            "/Create", "/SC", "HOURLY", "/MO", "1", "/TN", &name, "/TR", &action,
        ])
        .output()
        .map_err(|e| e.to_string())?;
    if !r.status.success() {
        return Err(format!(
            "Could not configure hourly update task: {}",
            String::from_utf8_lossy(&r.stderr)
        ));
    }
    Ok(())
}
fn watch(target: &Path) -> Result<(), String> {
    let target = canonical(target)?;
    let saved = state(&target).ok_or("No patch state for this launcher")?;
    let script = r#"$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; [Console]::OutputEncoding=New-Object System.Text.UTF8Encoding; $r=Invoke-RestMethod -Uri $env:PATCH_API -Headers @{'User-Agent'='Horizon-Patcher'}; $a=@($r.assets | Where-Object {$_.name -eq 'HorizonPatcher.exe'}); if($a.Count -ne 1 -or $a[0].digest -notmatch '^sha256:[0-9a-fA-F]{64}$' -or $a[0].size -gt 157286400){throw 'No verifiable update asset'}; @{tag=$r.tag_name; url=$a[0].browser_download_url; digest=$a[0].digest} | ConvertTo-Json -Compress"#;
    let output = ps(script, &[("PATCH_API", API)])?;
    if !output.status.success() {
        return Err("Could not fetch a verifiable patcher release".into());
    }
    let release: serde_json::Value =
        serde_json::from_slice(&output.stdout).map_err(|e| e.to_string())?;
    let tag = release["tag"].as_str().ok_or("Missing tag")?;
    if saved["build_tag"].as_str() == Some(tag)
        && saved["installed_sha256"].as_str() == Some(hash_file(&target)?.as_str())
    {
        return Ok(());
    }
    let url = release["url"].as_str().ok_or("Missing asset URL")?;
    if !url.starts_with(ASSET_PREFIX) {
        return Err("Unexpected download origin".into());
    }
    let expected = release["digest"]
        .as_str()
        .and_then(|s| s.strip_prefix("sha256:"))
        .ok_or("Missing digest")?;
    let dir = state_dir(&target)?;
    let tmp = dir.join(format!("download-{}.exe", std::process::id()));
    if tmp.exists() {
        return Err("Update temporary file already exists".into());
    }
    let download = r#"$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:PATCH_URL -OutFile $env:PATCH_FILE"#;
    let tmp_s = tmp.to_string_lossy();
    let out = ps(download, &[("PATCH_URL", url), ("PATCH_FILE", &tmp_s)])?;
    if !out.status.success() {
        let _ = fs::remove_file(&tmp);
        return Err("Update download failed".into());
    }
    if !hash_file(&tmp)?.eq_ignore_ascii_case(expected) {
        let _ = fs::remove_file(&tmp);
        return Err("Update checksum mismatch".into());
    }
    let status = Command::new(&tmp)
        .arg("--apply")
        .arg(&target)
        .status()
        .map_err(|e| e.to_string())?;
    let _ = fs::remove_file(&tmp);
    if !status.success() {
        return Err("Update was not applied; it will retry later".into());
    }
    Ok(())
}
fn run() -> Result<(), String> {
    let args: Vec<_> = env::args_os().collect();
    match args.get(1).and_then(|s| s.to_str()) {
        Some("--watch") => watch(Path::new(args.get(2).ok_or("Missing target")?)),
        Some("--apply") => apply(Path::new(args.get(2).ok_or("Missing target")?)),
        Some("--install") => {
            let target = Path::new(args.get(2).ok_or("Missing target")?);
            apply(target)?;
            install_task(target).map_err(|e| {
                format!("Launcher patched, but automatic updates were not installed: {e}")
            })?;
            println!("Hourly update check installed.");
            Ok(())
        }
        None => {
            println!("Horizon Privacy Patcher {BUILD_TAG}\nOnly supported official or previously patched files are modified.");
            let target = choose()?;
            apply(&target)?;
            match install_task(&target) {
                Ok(()) => println!("Hourly update check installed."),
                Err(e) => println!("Patched, but automatic updates were not installed: {e}"),
            };
            println!("Press Enter to exit.");
            let _ = io::stdin().read_line(&mut String::new());
            Ok(())
        }
        _ => Err("Unknown option".into()),
    }
}
fn main() {
    if let Err(e) = run() {
        if env::args_os().nth(1).as_deref() == Some(std::ffi::OsStr::new("--watch")) {
            if let Some(target) = env::args_os()
                .nth(2)
                .and_then(|p| canonical(Path::new(&p)).ok())
            {
                if let Ok(dir) = state_dir(&target) {
                    let _ = fs::write(dir.join("last-update-error.txt"), &e);
                }
            }
        }
        eprintln!("Error: {e}");
        if env::args_os().len() == 1 {
            println!("Press Enter to exit.");
            let _ = io::stdin().read_line(&mut String::new());
        }
        std::process::exit(1)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn refuses_unknown_binary() {
        assert!(eligible("abc", "ABC", None));
        assert!(eligible("old", "other", Some("OLD")));
        assert!(!eligible("bad", "good", Some("old")));
    }
    #[test]
    fn strips_windows_verbatim_prefixes() {
        assert_eq!(
            plain_windows_path(Path::new(r"\\?\C:\launcher.exe")),
            r"C:\launcher.exe"
        );
        assert_eq!(
            plain_windows_path(Path::new(r"\\?\UNC\server\share\launcher.exe")),
            r"\\server\share\launcher.exe"
        );
    }
    #[cfg(windows)]
    #[test]
    fn refuses_to_replace_a_running_target() {
        let dir = env::temp_dir().join(format!(
            "horizon-patcher-running-test-{}",
            std::process::id()
        ));
        fs::create_dir_all(&dir).unwrap();
        let target = dir.join("horizon-launcher.exe");
        fs::copy(env::var_os("COMSPEC").expect("Windows COMSPEC"), &target).unwrap();
        let mut child = Command::new(&target)
            .args(["/c", "ping -n 30 127.0.0.1 >nul"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        std::thread::sleep(std::time::Duration::from_millis(800));
        let result = is_not_running(&canonical(&target).unwrap());
        let _ = child.kill();
        let _ = child.wait();
        let _ = fs::remove_dir_all(dir);
        assert!(result.is_err(), "a running launcher must not be replaced");
    }
    #[test]
    fn computes_sha256() {
        assert_eq!(
            hash_bytes(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }
}
