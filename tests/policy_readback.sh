#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
node - "$root" <<'NODE'
const assert = require('node:assert/strict');
const {reconcile} = require(process.argv[2] + '/plugin/bin/policy-readback.cjs');
const own = '# /etc/systemd/sleep.conf.d/90-hibermachy.conf\n[Sleep]\nHibernateDelaySec=9000s\nHibernateOnACPower=no\n';
const run = args => { assert.deepEqual(args, ['timespan', '2h']); return {status:0, stdout:'      μs: 7200000000\n'}; };
let r = reconcile(own + '# /etc/systemd/sleep.conf.d/99-admin.conf\n[Sleep]\nHibernateDelaySec=2h\nHibernateOnACPower=yes\n[Other]\nHibernateDelaySec=1s\n', run);
assert.equal(r.requested.hibernateDelaySeconds,9000);
assert.deepEqual(r.effective,{hibernateDelaySeconds:7200,hibernateOnAcPower:true});
assert.deepEqual(r.provenance,['/etc/systemd/sleep.conf.d/99-admin.conf']);
assert.equal(reconcile(own+'HibernateDelaySec=\n',()=>({status:1})).effective,null);
assert.equal(reconcile('# /etc/systemd/sleep.conf\n[Sleep]\nHibernateDelaySec=1s\nHibernateOnACPower=yes',run).requested,null);
assert.equal(reconcile(own+'# /etc/systemd/sleep.conf.d/99-admin.conf\nHibernateDelaySec=1s',run).effective.hibernateDelaySeconds,9000);
NODE
