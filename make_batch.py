"""Point every dataset at its newly uploaded file.
  python3 make_batch.py prepare overview=<id> deep=<id> yesterday=<id> csp=<id>   -> prints ArtifactData batch writes (JSON)
  python3 make_batch.py commit     -> after the batch succeeded: bumps stored versions, records new asset ids, prints old asset ids to delete
If the batch is refused for a version mismatch, list collection "datasets", copy the versions shown into state.json "dataset_versions", and prepare again."""
import json, sys, datetime
key={'overview':'b2i_snapshot.json','deep':'b2i_deep_snapshot.json','yesterday':'b2i_yesterday_snapshot.json','csp':'b2i_csp_snapshot.json'}
st=json.load(open('state.json'))
if sys.argv[1]=='prepare':
    new=dict(a.split('=') for a in sys.argv[2:])
    now=datetime.datetime.now().astimezone().isoformat(timespec='minutes')
    writes=[]
    for k,fname in key.items():
        for ds in st['files'][fname]['datasets']:
            if ds in st['dataset_versions']:
                writes.append({'op':'update','collection':'datasets','doc_id':ds,'if_version':st['dataset_versions'][ds],
                               'data':{'source':{'url':'/_blob/'+new[k]},'updated':{'at':now}}})
            else:  # a dataset added since the last publish: create it
                meta=st.get('new_dataset_meta',{}).get(ds,{'title':ds,'description':''})
                writes.append({'op':'set','collection':'datasets','doc_id':ds,
                               'data':{'title':meta['title'],'description':meta['description'],'source':{'kind':'file','url':'/_blob/'+new[k],'name':fname,'format':'json'},
                                       'updated':{'at':now,'by':'Claude (Metabase / Snowflake snapshot)'},'fixed':True}})
    st['pending']={key[k]:new[k] for k in key}
    json.dump(st,open('state.json','w'),indent=1)
    print(json.dumps(writes))
elif sys.argv[1]=='commit':
    pend=st.pop('pending'); old=[]
    for fname,nid in pend.items():
        ent=st['files'][fname]
        if ent['asset_id']!=nid: old.append(ent['asset_id'])
        ent['asset_id']=nid
        for ds in ent['datasets']: st['dataset_versions'][ds]=st['dataset_versions'].get(ds,0)+1
    st['last_publish']=datetime.datetime.now().astimezone().isoformat(timespec='minutes')
    json.dump(st,open('state.json','w'),indent=1)
    print(json.dumps({'delete_asset_ids':old}))
