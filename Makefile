artifact_id := 625118357
docset_path := wezterm.docset

docset: build/artifact_${artifact_id}
	@echo 'do not make docset!'
	@mkdir -p ${docset_path}/Contents/Resources/Documents
	@cp Info.plist ${docset_path}/Contents
	@cp build/artifact_${artifact_id}/*.css ${docset_path}/Contents/Resources/Documents/
	@cp build/artifact_${artifact_id}/*.js ${docset_path}/Contents/Resources/Documents/
	@cp -r build/artifact_${artifact_id}/javascript ${docset_path}/Contents/Resources/Documents/

artifacts:
	# 将来はここからartifactを決定する
	curl -Ls \
		-H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		'https://api.github.com/repos/wez/wezterm/actions/artifacts?name=github-pages' | jqp '.artifacts[] | select (.expired==false)'

build/artifact_${artifact_id}: build/artifact_${artifact_id}.zip
	@echo 'unzip archive!'
	@unzip -o build/artifact_${artifact_id}.zip -d build/artifact_${artifact_id}
	@cd build/artifact_${artifact_id} && tar xf artifact.tar
	@touch build/artifact_${artifact_id}

build/artifact_${artifact_id}.zip: build/artifact.json
	@echo 'download archive!'
	$(eval ARCHIVE_URL="$(shell cat build/artifact.json | jq -r '.archive_download_url')")
	@curl -L \
		-H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		-o build/artifact_${artifact_id}.zip \
		${ARCHIVE_URL} 2> /dev/null

build/artifact.json: build
	@echo 'download metadata!'
	@curl -Ls \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}"\
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/wez/wezterm/actions/artifacts/${artifact_id} > build/artifact.json

build:
	mkdir build

clean:
	rm -rf ./build
	rm -rf ./${docset_path}
