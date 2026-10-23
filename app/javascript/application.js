// Entry point for the build script in your package.json
import '@hotwired/turbo-rails';
import 'chartkick/chart.js';
import './charts';
import './controllers';
import * as bootstrap from 'bootstrap';
import { registerServiceWorker } from './pwa';

registerServiceWorker();
