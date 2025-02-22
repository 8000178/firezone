use anyhow::Result;
use clap::Parser;
use connlib_client_shared::{file_logger, Callbacks, Error, Session};
use firezone_cli_utils::{block_on_ctrl_c, setup_global_subscriber, CommonArgs};
use secrecy::SecretString;
use std::path::PathBuf;

fn main() -> Result<()> {
    let cli = Cli::parse();

    let (layer, handle) = cli.log_dir.as_deref().map(file_logger::layer).unzip();
    setup_global_subscriber(layer);

    let mut session = Session::connect(
        cli.common.api_url,
        SecretString::from(cli.common.token),
        cli.common.firezone_id,
        CallbackHandler { handle },
    )
    .unwrap();
    tracing::info!("new_session");

    block_on_ctrl_c();

    session.disconnect(None);
    Ok(())
}

#[derive(Clone)]
struct CallbackHandler {
    handle: Option<file_logger::Handle>,
}

impl Callbacks for CallbackHandler {
    type Error = std::convert::Infallible;

    fn roll_log_file(&self) -> Option<PathBuf> {
        self.handle
            .as_ref()?
            .roll_to_new_file()
            .unwrap_or_else(|e| {
                tracing::debug!("Failed to roll over to new file: {e}");
                let _ = self.on_error(&Error::LogFileRollError(e));

                None
            })
    }
}

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(flatten)]
    common: CommonArgs,

    /// File logging directory. Should be a path that's writeable by the current user.
    #[arg(short, long, env = "LOG_DIR")]
    log_dir: Option<PathBuf>,
}
