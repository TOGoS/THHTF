run-unit-tests:
	rdmd -Isrc/main/d -main -unittest src/main/d/togos/file/thhtf.d

clean:
	rm -f .temp* .*.temp
