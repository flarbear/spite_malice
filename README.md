# tic_tac_toe

A boardgame.io project to implement an online web-based version of the
Spite and Malice card game. The server side is implemented in Node.js
using the boardgame.io facilities and the client side is implemented
in Flutter using the Dart boardgame_io package.

## Getting Started

You will need to execute the following commands to get this project up and running.

### Building the Flutter app

First, you will need to build the web pages from the Flutter sources for the
boardgame.io server to serve. You will need to install Flutter as described in
the [Flutter getting started](https://flutter.dev/docs/get-started/install)
pages.

Once Flutter is installed and this project is cloned, you need to execute the
following commands in the root of this repository to initialize flutter and
install the appropriate web sources:

```sh
flutter config --enable-web
flutter devices
```

At this point you should see entries in the supported flutter devices for
`web-server` and `chrome` if you have Chrome installed. The code will
run on a variety of browsers (FireFox and Chrome have been tested by the
author), but those are the default deployment devices for most installs
of Flutter web. If you see either of those, then you have correctly enabled
Flutter for web. If you have trouble, you can check the
[Getting started with Flutter for web](https://flutter.dev/docs/get-started/web)
pages for more information.

Next you need to build the web pages from the flutter source. This can be
done with 2 commands:

```sh
flutter pub get
flutter build web
```

The first command is only needed initially, and any time you change the
dependencies in `pubspec.yaml`. The second command actually does the work
of building the sources in the `build/web` directory.

### Setting up and running the server

Next, for the server side, you will need to initialize the support for
the boardgame.io server. Again from the root of this repo, run the following
commands:

```sh
npm install boardgame.io
npm install esm
npm install koa-static
```

Then you run the server with the following command:

```sh
npm start
```

### Running the example

The last step is easiest. Simply connect to the boardgame.io server you
just ran by opening a browser and connecting to `localhost:<PORT>` where
`<PORT>` is the port that the Server mentioned it was serving the `App`
on. (Note that there is no boardgame.io App.js here, the server is only
being used to run the game and the Flutter code is replacing the front
end that would normally go in `App.js`.)

### Deployment on a web server

This installation is designed to be easily served on a shared web hosting
site taht supports installation of Node.js apps. Use your cpanel/whm interface
to create a new Node.js app on your server and then place the following files
into the associated directory:

```
nodejsdir -> package.json
             src -> Server.js
                    Game.js
             build -> web -> *
```

Use your web host provider's facilities to run the appropriate install
scripts and start the app. The 'start' script in the `package.json` file
runs the web server that will both run the game and serve the necessary
Flutter files to a web browser. If you connect to the URL associated with
the node app, it should show the Spite&Malice Lobby and allow you to
create games and play with friends.
