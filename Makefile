test:
	dzil smoke --release --author && dzil cover -test -report codecov && dzil xtest
tidy:
	find . -name '*.p?.bak' -delete
	find . -name '*.p[lm]' -o -name '*.t' | xargs perltidy -pro=t/rc/.perltidyrc --backup-and-modify-in-place -bext=tidyup
	find . -name '*.tidyup' -delete

