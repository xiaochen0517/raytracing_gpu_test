mod app;

use crate::app::App;
use winit::event_loop::EventLoop;

pub fn run() -> anyhow::Result<()> {
    env_logger::init();

    let event_loop = EventLoop::with_user_event().build()?;
    let mut app = App::new("WGPU Raytracing Test".to_string().into());
    event_loop.run_app(&mut app)?;

    Ok(())
}
