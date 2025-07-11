import ReactOnRails from 'react-on-rails';

import HelloWorld from '../bundles/HelloWorld/components/HelloWorld';
import FilesIndex from '../bundles/HelloWorld/components/FilesIndex';
import FileModal from '../bundles/HelloWorld/components/FileModal';
import ViewFile from '../bundles/HelloWorld/components/ViewFile';

// This is how react_on_rails can see the HelloWorld in the browser.
ReactOnRails.register({
  HelloWorld,
  FilesIndex,
  FileModal,
  ViewFile,
});
