import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from '../src/server.mjs';
import {MemoryStore} from '../src/store.mjs';
async function app(t,store=new MemoryStore()){const s=createServer(store);await new Promise(r=>s.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>s.close(r)));return 'http://127.0.0.1:'+s.address().port;}
test('catalog, lookup and missing product',async t=>{const u=await app(t);const data=await fetch(u+'/api/products').then(r=>r.json());assert.equal(data.products.length,4);assert.equal((await fetch(u+'/api/products/desk-lamp')).status,200);assert.equal((await fetch(u+'/api/products/unknown')).status,404);});
test('readiness fails when store is unavailable while liveness remains healthy',async t=>{const store=new MemoryStore();store.ready=()=>{throw Error('offline');};const u=await app(t,store);assert.equal((await fetch(u+'/readyz')).status,503);assert.equal((await fetch(u+'/healthz')).status,200);});
test('static files include security headers and do not expose source files',async t=>{const u=await app(t);const page=await fetch(u+'/');assert.equal(page.status,200);assert.match(page.headers.get('content-security-policy'),/frame-ancestors 'none'/);assert.equal((await fetch(u+'/src/server.mjs')).status,404);assert.equal((await fetch(u+'/%2e%2e%2fpackage.json')).status,404);});

test('catalog cannot be mutated through the public API',async t=>{const u=await app(t);assert.equal((await fetch(u+'/api/orders',{method:'POST',body:'{}'})).status,404);assert.equal((await fetch(u+'/api/products',{method:'DELETE'})).status,404);assert.equal((await fetch(u+'/api/products').then(r=>r.json())).products.length,4);});
