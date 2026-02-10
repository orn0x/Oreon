cname:
	flutter pub global activate rename
	flutter pub global run rename setAppName --targets ios,android --value "Oreon"
logo:
	flutter pub get
	flutter pub run flutter_launcher_icons:main
update:
	git fetch
	git merge