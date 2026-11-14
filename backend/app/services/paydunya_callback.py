"""Bounded JSON and form decoding for the payment notification endpoint."""
import json,re
from urllib.parse import parse_qsl
from fastapi import HTTPException,Request

async def read_paydunya_callback(request: Request) -> dict:
    body=bytearray()
    async for chunk in request.stream():
        body.extend(chunk)
        if len(body)>65536:
            raise HTTPException(status_code=413,detail="Notification trop volumineuse")
    try:
        media=request.headers.get("content-type","").split(";")[0].strip().lower()
        if media=="application/json":
            result=json.loads(body)
            if not isinstance(result,dict):raise ValueError()
            return result
        if media!="application/x-www-form-urlencoded":
            raise HTTPException(status_code=415,detail="Format de notification non pris en charge")
        pairs=parse_qsl(body.decode("utf-8"),keep_blank_values=True,max_num_fields=200)
        result={};seen=set()
        for key,value in pairs:
            if key in seen:raise ValueError()
            seen.add(key)
            if key=="data":
                decoded=json.loads(value)
                if not isinstance(decoded,dict) or "data" in result:raise ValueError()
                result["data"]=decoded
                continue
            if not re.fullmatch(r"data(?:\[[A-Za-z0-9_-]+\]){1,8}",key):raise ValueError()
            parts=re.findall(r"[^\[\]]+",key)
            cursor=result
            for part in parts[:-1]:
                node=cursor.setdefault(part,{})
                if not isinstance(node,dict):raise ValueError()
                cursor=node
            if parts[-1] in cursor:raise ValueError()
            cursor[parts[-1]]=value
        if not isinstance(result.get("data"),dict):raise ValueError()
        return result
    except (ValueError,UnicodeError,TypeError):
        raise HTTPException(status_code=400,detail="Notification de paiement invalide")
