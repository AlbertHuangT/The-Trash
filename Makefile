RN_DIR := the-trash-rn

.PHONY: install start ios android pods lint format contracts contracts-strict migrations-check migrations-check-strict migrations-sync doctor legacy-open

install:
	pnpm --dir "$(RN_DIR)" install

start:
	pnpm --dir "$(RN_DIR)" exec expo start --dev-client --tunnel --clear

ios:
	pnpm --dir "$(RN_DIR)" run ios

android:
	pnpm --dir "$(RN_DIR)" run android

pods:
	pnpm --dir "$(RN_DIR)" run pods:install

lint:
	pnpm --dir "$(RN_DIR)" run lint

format:
	pnpm --dir "$(RN_DIR)" run format

contracts:
	bash scripts/check_backend_contracts.sh

contracts-strict:
	bash scripts/check_backend_contracts.sh --strict

migrations-check:
	bash scripts/check_migration_mirror.sh

migrations-check-strict:
	bash scripts/check_migration_mirror.sh --strict

migrations-sync:
	bash scripts/sync_migration_mirror.sh

doctor:
	bash scripts/check_backend_contracts.sh --strict
	bash scripts/check_migration_mirror.sh --strict

legacy-open:
	open "legacy/swift-ios/The Trash.xcodeproj"
