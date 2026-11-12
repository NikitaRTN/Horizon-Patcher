use std::{path::PathBuf, thread};
use tao::{
    dpi::LogicalSize,
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoopBuilder, EventLoopProxy},
    platform::{run_return::EventLoopExtRunReturn, windows::WindowExtWindows},
    window::WindowBuilder,
};
use wry::{WebView, WebViewBuilder};

const HTML: &str = include_str!("gui.html");

// Windows 11 otherwise draws the user's accent color around a frameless window.
// Change only this window, keeping rounded corners, resizing and the system shadow.
fn hide_native_border(window: &tao::window::Window) {
    #[link(name = "dwmapi")]
    extern "system" {
        fn DwmSetWindowAttribute(
            hwnd: isize,
            attribute: u32,
            value: *const std::ffi::c_void,
            size: u32,
        ) -> i32;
    }
    const DWMWA_BORDER_COLOR: u32 = 34;
    const DWMWA_COLOR_NONE: u32 = 0xffff_fffe;
    // SAFETY: hwnd belongs to a live Tao window; the COLORREF pointer and size
    // remain valid for this synchronous call. Older Windows versions may reject
    // this optional attribute; that must not prevent the patcher from starting.
    unsafe {
        let _ = DwmSetWindowAttribute(
            window.hwnd(),
            DWMWA_BORDER_COLOR,
            (&DWMWA_COLOR_NONE as *const u32).cast(),
            std::mem::size_of::<u32>() as u32,
        );
    }
}

enum Message {
    Ipc(String),
    Scanned(Vec<PathBuf>),
    Installed(Result<(), String>),
    SmokeTimeout,
}

fn post(webview: &WebView, value: serde_json::Value) {
    // JSON is encoded by serde, never concatenated from file paths or errors.
    let _ = webview.evaluate_script(&format!("window.onNativeMessage({value});"));
}
fn files_message(webview: &WebView, paths: &[PathBuf], selected: usize) {
    let files: Vec<_> = paths.iter().map(|p| crate::plain_windows_path(p)).collect();
    post(
        webview,
        serde_json::json!({"type":"files", "files":files, "selected":selected}),
    );
}
fn scan(proxy: EventLoopProxy<Message>) {
    thread::spawn(move || {
        let _ = proxy.send_event(Message::Scanned(
            crate::candidates().into_iter().take(100).collect(),
        ));
    });
}
fn install(proxy: EventLoopProxy<Message>, target: PathBuf) {
    thread::spawn(move || {
        let result = crate::canonical(&target).and_then(|p| {
            crate::remove_legacy_task(&p)?;
            crate::apply(&p)
        });
        let _ = proxy.send_event(Message::Installed(result));
    });
}
pub fn run(smoke: bool) -> Result<(), String> {
    let mut event_loop = EventLoopBuilder::<Message>::with_user_event().build();
    let proxy = event_loop.create_proxy();
    let window = WindowBuilder::new()
        .with_title("Horizon Privacy Patcher")
        .with_decorations(false)
        .with_inner_size(LogicalSize::new(1180.0, 760.0))
        .with_min_inner_size(LogicalSize::new(820.0, 620.0))
        .build(&event_loop)
        .map_err(|e| format!("Не удалось создать окно: {e}"))?;
    hide_native_border(&window);
    if smoke {
        let watchdog = proxy.clone();
        thread::spawn(move || {
            thread::sleep(std::time::Duration::from_secs(30));
            let _ = watchdog.send_event(Message::SmokeTimeout);
        });
    }
    let ipc_proxy = proxy.clone();
    let initial_html_navigation = std::cell::Cell::new(true);
    let webview = WebViewBuilder::new()
        .with_html(HTML)
        // WebView2 represents NavigateToString as a data: navigation. Permit
        // that initial local document only; all subsequent external navigation is denied.
        .with_navigation_handler(move |url| {
            if url == "about:blank" {
                return true;
            }
            if initial_html_navigation.get()
                && url.starts_with("data:text/html;charset=utf-8;base64,")
            {
                initial_html_navigation.set(false);
                return true;
            }
            false
        })
        .with_ipc_handler(move |request| {
            let _ = ipc_proxy.send_event(Message::Ipc(request.body().clone()));
        })
        .build(&window)
        .map_err(|e| {
            format!("Не удалось открыть интерфейс. Установите Microsoft Edge WebView2 Runtime: {e}")
        })?;
    let mut paths = Vec::<PathBuf>::new();
    let mut busy = false;
    let mut smoke_ok = false;
    let mut smoke_download = false;
    event_loop.run_return(|event, _, flow| {
        *flow = ControlFlow::Wait;
        match event {
            Event::WindowEvent { event: WindowEvent::CloseRequested, .. } if !busy => *flow = ControlFlow::Exit,
            Event::UserEvent(Message::Scanned(found)) => {
                busy = false; paths = found; files_message(&webview, &paths, 0);
                if smoke {
                    let _ = webview.evaluate_script(r#"(() => { const b=document.getElementById('btnDownload'), c=document.getElementById('starCanvas'), v=document.getElementById('compatibleVersion').textContent; let ok=!!b && !b.disabled && !!c && c.width>0 && !!v && document.body.getBoundingClientRect().width>0; window.onNativeMessage({type:'init',version:null,tag:''}); ok=ok && b.disabled; window.onNativeMessage({type:'init',version:v,tag:'smoke'}); window.onNativeMessage({type:'busy',kind:'scan'}); ok=ok && !b.disabled; if(ok)b.click(); window.ipc.postMessage(JSON.stringify({action:'smoke_report',ok})); })();"#);
                }
            }
            Event::UserEvent(Message::SmokeTimeout) if smoke => { *flow = ControlFlow::Exit; }
            Event::UserEvent(Message::Installed(result)) => {
                busy = false;
                match result {
                    Ok(()) => post(&webview, serde_json::json!({"type":"installed", "ok":true})),
                    Err(error) => post(&webview, serde_json::json!({"type":"installed", "ok":false, "error":friendly_error(&error)})),
                }
            }
            Event::UserEvent(Message::Ipc(raw)) => {
                if raw.len() > 1024 { return; }
                let Ok(message) = serde_json::from_str::<serde_json::Value>(&raw) else { return; };
                match message.get("action").and_then(|v| v.as_str()).unwrap_or("") {
                    "ready" => {
                        post(&webview, serde_json::json!({"type":"init", "version":crate::compatible_version(crate::BUILD_TAG), "tag":crate::BUILD_TAG}));
                        if !busy { busy=true; post(&webview, serde_json::json!({"type":"busy", "kind":"scan"})); scan(proxy.clone()); }
                    }
                    "scan" if !busy => { busy=true; post(&webview, serde_json::json!({"type":"busy", "kind":"scan"})); scan(proxy.clone()); }
                    "browse" if !busy => {
                        if let Some(path) = rfd::FileDialog::new().set_title("Выберите лаунчер Horizon").add_filter("Приложения", &["exe"]).pick_file() {
                            let selected = paths.iter().position(|p| p == &path).unwrap_or_else(|| { paths.push(path); paths.len() - 1 });
                            files_message(&webview, &paths, selected);
                        }
                    }
                    "install" if !busy => {
                        if let Some(target) = message.get("index").and_then(|v| v.as_u64()).and_then(|i| usize::try_from(i).ok()).and_then(|i| paths.get(i)).cloned() {
                            busy=true; post(&webview, serde_json::json!({"type":"busy", "kind":"install"})); install(proxy.clone(), target);
                        }
                    }
                    "download" if smoke => { smoke_download=true; }
                    "smoke_report" if smoke => { smoke_ok=smoke_download && message.get("ok").and_then(|v|v.as_bool())==Some(true); *flow=ControlFlow::Exit; }
                    "download" => {
                        if let Some(version) = crate::compatible_version(crate::BUILD_TAG) {
                            if let Err(e) = open::that(crate::official_setup_url(version)) { post(&webview, serde_json::json!({"type":"error", "error":format!("Не удалось открыть ссылку: {e}")})); }
                        }
                    }
                    "minimize" => window.set_minimized(true),
                    "maximize" => window.set_maximized(!window.is_maximized()),
                    "close" if !busy => *flow = ControlFlow::Exit,
                    "drag" => { let _ = window.drag_window(); }
                    _ => {}
                }
            }
            _ => {}
        }
    });
    if smoke && !smoke_ok {
        return Err("GUI smoke test failed or timed out".into());
    }
    Ok(())
}
fn friendly_error(error: &str) -> String {
    if error.contains("Unsupported or modified") {
        "Неизвестная или изменённая версия лаунчера. Файл не изменён.".into()
    } else if error.contains("Close the selected launcher") {
        "Закройте лаунчер и попробуйте ещё раз.".into()
    } else {
        format!("Не удалось применить патч: {error}")
    }
}
