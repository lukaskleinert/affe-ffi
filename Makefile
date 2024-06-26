.PHONY: affe hm web all clean test vsc_extension

all: affe hm web test vsc_extension


affe:
	dune build lang/affe/affe.exe

hm:
	dune build lang/hm/hm.exe

test:
	dune runtest

vsc_extension:
	@if [ -d ~/.vscode/extensions/ ]; then \
		rm -rf ~/.vscode/extensions/affe/ ; \
		cp -r vsc_extension/affe ~/.vscode/extensions/affe ; \
	else echo "no '~/.vscode/extensions/' folder found" >&2 ; \
	fi

%.affe: affe
	dune exec -- lang/affe/affe.exe lang/affe/affi/examples/$@ -a out/affiout.ml
	@echo "-----------------ocaml-----------------"
	@cat out/affiout.ml
	@echo "------------------out------------------"
	@dune build out/
	@dune exec out/affiout.exe

interactive: affe
	dune exec lang/affe/affe.exe

clean:
	dune clean
	rm -f www/affe_www.bc.js
	rm -f www/jsootop.bc.js

web:
	dune build lang/affe/affe_www.bc.js --profile=release
	dune build zoo/web/jsootop/jsootop.bc.js --profile=release
	@mkdir -p www/builtin
	@cp  out/builtin/* www/builtin/
	@mkdir -p www/examples
	@cp lang/affe/affi/examples/* www/examples/
	@cp _build/default/lang/affe/affe_www.bc.js www
	@cp _build/default/zoo/web/jsootop/jsootop.bc.js www

github_pages: web
	@cd ../lukaskleinert.github.io/affe-ffi ; git pull --rebase
	@cp -r www/* ../lukaskleinert.github.io/affe-ffi
	@cd ../lukaskleinert.github.io/affe-ffi ; git add . ; git commit -m "auto upload" ; git push