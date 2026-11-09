# Publish Menu Magnet on GitHub

This repository is ready for **GitHub Pages** using a static HTML site in `docs/` — no npm install, Node build, Jekyll theme, or GitHub Actions file is necessary.

## Create the repository

1. Sign in to [GitHub](https://github.com/) and select **New repository** (`https://github.com/new`).
2. Repository name: `menu-magnet`.
3. Description: `A tactile, velocity-aware macOS menu navigation enhancement built with Hammerspoon and Lua.`
4. Choose **Public** if you want GitHub Pages on the GitHub Free plan.
5. Leave the options for initializing a README, `.gitignore`, and licence **unchecked** since this package already contains README and `.gitignore`. No licence has been selected yet.
6. Click **Create repository**.

## Upload the files

From the repository page, choose **uploading an existing file** or **Add file → Upload files**. Drag **the contents of the extracted `Menu-Magnet-Website` folder**, not the ZIP itself, into GitHub. The folder structure must stay intact. Write a commit message such as `Add Menu Magnet website and documentation`, and commit to the `main` branch.

Make sure you can see `README.md` and the `docs` and `src` folders in the repository root.

> If GitHub's browser upload does not preserve nested folders as expected, use GitHub Desktop or Git on your Mac to add the folder. Never upload your entire personal `~/.hammerspoon/init.lua`, which may include unrelated automation or private paths.

## Publish GitHub Pages

1. Open the repository's **Settings** tab.
2. Choose **Pages** in the sidebar.
3. Under **Build and deployment**, set **Source → Deploy from a branch**.
4. Select **Branch: `main`**, **Folder: `/docs`**, then **Save**.
5. GitHub will provide a Pages address (commonly `https://YOUR-USERNAME.github.io/menu-magnet/`).

The website homepage is your provided Gesture Studio, including the six profiles, synthesized original sounds and supported-browser MP4 export. It includes a direct downloadable copy of the engine at `docs/download/MenuMagnet.lua` (identical to `src/MenuMagnet.lua`). Keep them in sync if you update the source. The site's page structure uses relative assets, so it works when hosted below a project repository path. `docs/.nojekyll` disables Jekyll processing.

Reference: [GitHub's official publishing-source instructions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

## Before sharing publicly

- Decide whether to add a software licence.
- Test the Lua engine locally on the macOS versions and apps you intend to support.
- Verify you did not upload any other Hammerspoon config files or personal paths.
- Replace any GitHub URL in your social profiles with the actual repository and Pages URL after publishing.
- Optional: add screenshots or a screen recording once you have captured the real trackpad interactions on your Mac.
