artifact: build/artifacts.json build/artifact.zip
	$(eval ARCHIVE_URL="$(shell cat build/artifacts.json | jq -r '.archive_download_url')")
	curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		-o build/artifact.zip \
		${ARCHIVE_URL}

build/artifacts.json: build
	curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/wez/wezterm/actions/artifacts/624521122 > build/artifacts.json
# wget https://github.com/wez/wezterm/suites/11923249851/artifacts/624521122

build:
	mkdir ./build

clean:
	rm -rf ./build
