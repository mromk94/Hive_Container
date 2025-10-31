def simple_hash_embedding(text,dim=128):
    vec=[0]*dim
    for i,ch in enumerate(text[:1024]):
        vec[i%dim]+=ord(ch)
    s=sum(abs(x) for x in vec) or 1
    return [x/s for x in vec]

if __name__=='__main__':
    print(len(simple_hash_embedding('demo')))
