docset_path := wezterm.docset

docset: build/artifact
	@echo 'do not make docset!'
	@mkdir -p ${docset_path}/Contents/Resources/Documents
	@cp Info.plist ${docset_path}/Contents
	@cp build/artifact/*.css ${docset_path}/Contents/Resources/Documents/
	@cp build/artifact/*.js ${docset_path}/Contents/Resources/Documents/
	@cp -r build/artifact/javascript ${docset_path}/Contents/Resources/Documents/

build/artifact: build/artifact.zip
	@echo 'unzip archive!'
	@unzip -o build/artifact.zip -d build/artifact
	@cd build/artifact && tar xf artifact.tar
	@touch build/artifact

build/artifact.zip: build/archive_download_url
	@echo 'download archive!'
	$(eval ARCHIVE_URL="$(shell cat build/archive_download_url)")
	@curl -L \
		-H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		-o build/artifact.zip \
		${ARCHIVE_URL} 2> /dev/null

build/archive_download_url: build
	@echo 'download metadata!'
	@curl -Ls \
		-H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		'https://api.github.com/repos/wez/wezterm/actions/artifacts?name=github-pages' | jq -r '.artifacts[] | select (.expired==false) | .archive_download_url' | head -1 > build/archive_download_url

build:
	mkdir build

clean:
	rm -rf ./build
	rm -rf ./${docset_path}
