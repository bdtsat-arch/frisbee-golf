# Frisbee Scoring App (Flutter Web)

A Flutter Web app for scoring Frisbee games.

## Features

- Select number of players: 2, 4, or 6
- Select number of holes: 9 or 18
- Score each hole for each player
- Navigate through holes
- View running totals and final scores

## Requirements

- Flutter SDK installed
- Dart SDK

## VSCode Help Search box

ctrl + shift + p

## How to Run

1. Ensure Flutter is installed and set up.
2. Run `flutter pub get` to install dependencies.
3. Run `flutter run -d chrome` to launch in Chrome browser.Also

Also run with ctrl+shift+B

## Build for Web

Run `flutter build web` to build for deployment.


## TO DO Before Publishing

[] Recreate a new recaptcha key on google console that is NOT in test mode and register github.io domain
[] Remove debug app check token (631033fb-9138-43b2-ba50-57e329144906) from html code
[] Remove all debug app check tokens from firebase console

Ver 8 Update
Home Tab Controls and Descriptions:
Added Description under Select Course
If selecting Custom Course, unlocks H1..End boxes.
If selecting Saved Course, locks down H1..End.
On History Tab, added Button for Continue Game if game was not completed and adds In Progress message on closed games.  If selecting Continue Game, game loads in Game Tab and moves to next uncompleted hole.