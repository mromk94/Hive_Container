import express from 'express';
const app=express();app.use(express.json());app.post('/handshake',(req,res)=>{console.log('handshake',req.body);res.json({ok:true})});app.listen(4000,()=>console.log('bridge up'));
