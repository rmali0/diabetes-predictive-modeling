all: results

results:
	Rscript run_all.R

quick:
	QUICK=1 Rscript run_all.R

test:
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'

.PHONY: all results quick test
