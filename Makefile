default:
	rdmd -Isrc/main/d -unittest src/main/d/test.d
	rm -f .temp* .*.temp
