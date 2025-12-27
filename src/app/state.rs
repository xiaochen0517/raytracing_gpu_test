use std::sync::Arc;
use winit::event_loop::ActiveEventLoop;
use winit::keyboard::KeyCode;
use winit::window::Window;

pub struct State {
    pub window: Arc<Window>,
}

impl State {
    pub async fn new(window: Arc<Window>) -> anyhow::Result<Self> {
        Ok(Self { window })
    }

    pub fn resize(&mut self, _width: u32, _height: u32) {
        // Handle resizing logic here
    }

    pub fn handle_key(&mut self, event_loop: &ActiveEventLoop, code: KeyCode, is_pressed: bool) {
        // 按下 Esc 键时退出应用程序
        if code == KeyCode::Escape && is_pressed {
            event_loop.exit();
        }
    }

    pub fn update(&mut self) {
        // Update application state here
    }

    pub fn render(&mut self) -> Result<(), wgpu::SurfaceError> {
        // Rendering logic here
        Ok(())
    }
}
