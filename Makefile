test:
	dzil test && dzil smoke --release --author && dzil xtest
tidy:
	dzil perltidy
