import {readFile} from 'node:fs/promises';
export class MemoryStore {
 mode='read-only-catalog';
 async ready(){await this.products();}
 async products(){return JSON.parse(await readFile(new URL('../data/products.json',import.meta.url),'utf8'));}
}
