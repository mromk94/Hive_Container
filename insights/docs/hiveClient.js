// Hive client placeholder
export async function postHandshake(baseUrl,p){return fetch(baseUrl+'/handshake',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)}).then(r=>r.json())}
