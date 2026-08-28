# minui-tailscale.pak

A [MinUI](https://github.com/shauninman/MinUI) and [NextUI](https://github.com/LoveRetro/NextUI) pak wrapping [`Tailscale`](https://tailscale.com/), a secure and easy-to-use VPN.

## Requirements

This pak is designed for the following MinUI Platforms and devices:

- `h700`: Anbernic RG35XX SP, RG SP (NextUI only)
- `m17`: M17
- `magicmini`: MagicX XU Mini M
- `miyoomini`: Miyoo Mini, Miyoo Mini Plus, Miyoo Mini Flip
- `my282`: Miyoo A30
- `my355`: Miyoo Flip
- `rg35xx`: Anbernic RG35XX
- `rg35xxplus`: Anbernic RG35XX Plus, RG-34XX, RG-35XX H, RG-35XX SP
- `rgb30`: Powkiddy RGB30
- `tg5040`: Trimui Brick (formerly `tg3040`), Trimui Smart Pro
- `tg5050`: Trimui Smart Pro S (NextUI only)
- `trimuismart`: Trimui Smart
- `zero28`: MagicX Mini Zero 28

The pak may work on other platforms and devices, but it has not been tested on them.

## Installation

1. Mount your MinUI SD card.
2. Download the latest release from Github. It will be named `Tailscale.pak.zip`.
3. Copy the zip file to the correct platform folder in the "/Tools" directory on the SD card. Please ensure the new zip file name is `Tailscale.pak.zip`.
4. Extract the zip in place, then delete the zip file.
5. Confirm that there is a `Tailscale.pak/launch.sh` file on your SD card.

Note: The platform folder name is based on the name of your device. For example, if you are using a TrimUI Brick, the folder is "tg3040". Alternatively, if you're not sure which folder to use, you can copy the .pak folders to all the platform folders.

## Auth Key

To log in to Tailscale, you need an authentication key. This can be generated from the Tailscale admin console. The key can be either a reusable key or an ephemeral key. The key will need to be placed in a file called `authkey` in the root of the SD card. The file should contain only the key itself, with no extra spaces or newlines. The pak will look for this key when starting for the first time. Once started the key will be deleted.

1. Go to the Tailscale [keys page in the admin console](https://login.tailscale.com/admin/settings/keys).
2. Click on "Generate Auth Key".
3. Choose the type of key you want to generate (reusable or ephemeral).
4. Click "Generate Key" copy the key.
5. Create a file called `authkey` in the root of your SD card.
6. Paste the key into the `authkey` file and save the file.
7. Unmount your SD Card and insert it into your MinUI device.

## Usage

Browse to `Tools > Tailscale` and press `A` to enter the Pak.

### Start/Stop Tailscale

You can start or stop Tailscale from the app's main menu. When Tailscale is running, you will see a message indicating the PID of the Tailscale process.

### Start on Boot

You can enable or disable starting Tailscale on boot from the app's settings menu.

## Debug Logging

Debug logs are written to the `$SDCARD_PATH/.userdata/$PLATFORM/logs/` folder.

## Acknowledgements

- [MinUI](https://github.com/shauninman/MinUI) by [Shaun Inman](https://github.com/shauninman).
- [minui-list](https://github.com/josegonzalez/minui-list) and [minui-presenter](https://github.com/josegonzalez/minui-presenter) by [Jose Diaz-Gonzalez](https://github.com/josegonzalez).
- [NextUI](https://github.com/LoveRetro/NextUI) by [@ro8inmorgan](https://github.com/ro8inmorgan), [@frysee](https://github.com/frysee) and the rest of the NextUI contributors.
- Also, thank you, [Jose Diaz-Gonzalez](https://github.com/josegonzalez), for your pak repositories, which this project is based on.

## Custom login server (Headscale)

If you use a self-hosted Headscale or other custom login server, create a file named `loginserver` containing only the base URL of your login server (for example, `https://headscale.example.com`). Drop the file on the root of your SD card or directly into `$USERDATA_PATH/$PAK_NAME`. On launch, the pak cleans the value, moves it into `$USERDATA_PATH/$PAK_NAME/loginserver`, and automatically passes it to `tailscale up` using `--login-server`.

## License

This project is released under the MIT License. For more information, see the [LICENSE](LICENSE) file.
