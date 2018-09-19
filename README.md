
# react-native-video-poc

## Getting started

`$ npm install react-native-video-poc --save`

### Mostly automatic installation

`$ react-native link react-native-video-poc`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-video-poc` and add `RNVideoPoc.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNVideoPoc.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNVideoPocPackage;` to the imports at the top of the file
  - Add `new RNVideoPocPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-video-poc'
  	project(':react-native-video-poc').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-video-poc/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-video-poc')
  	```

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNVideoPoc.sln` in `node_modules/react-native-video-poc/windows/RNVideoPoc.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Video.Poc.RNVideoPoc;` to the usings at the top of the file
  - Add `new RNVideoPocPackage()` to the `List<IReactPackage>` returned by the `Packages` method


## Usage
```javascript
import RNVideoPoc from 'react-native-video-poc';

// TODO: What to do with the module?
RNVideoPoc;
```
  