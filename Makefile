.PHONY: push

# Pushes the current branch to all configured remotes (github and gitlab)
push:
	@echo "--> Pushing to all remotes (github & gitlab)..."
	git push github HEAD
	git push gitlab HEAD
