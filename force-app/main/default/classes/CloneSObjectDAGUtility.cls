public with sharing class CloneSObjectDAGUtility {

    private static String timeNow = String.valueOf(System.now());
    
    public static void main(List<CloneSObjectDAG.WrapperClass> wapList, Id attachmentRecord) {
        List<Attachment> attachmentList = new List<Attachment>();

        Attachment planAttachment = new Attachment(
            parentId = attachmentRecord,
            Name = 'Plan-' + timeNow + '.json'
        );

        List<Object> planBodyArray = new List<Object>();

        for(CloneSObjectDAG.WrapperClass wap : wapList) {

            List<Object> listObject = convertSobjectListToList(wap.records, wap.fieldsToRef, wap.sObjectName);
            System.debug(listObject);
            System.debug(JSON.serialize(listObject));

            Map<String, Object> objectAttachmentStructure = new Map<String, Object>();
            objectAttachmentStructure.put('records', listObject);

            if(!wap.hasSelfRelationship) {
                attachmentList.add(createAttachmentFile(wap.sObjectName, JSON.serializePretty(objectAttachmentStructure), attachmentRecord));
                planBodyArray.add(generatePlanRecord(wap.sObjectName, getFileName(wap.sObjectName)));
            } 
            else {
                system.debug('before reccursive calls ' + objectAttachmentStructure);
                system.debug('before reccursive calls == ' + wap.ifSelfRefThenFieldName);
                system.debug('before reccursive calls == ' + attachmentRecord);
                system.debug('before reccursive calls == ' + wap.sObjectName);
                List<Attachment> allSelfRefAttachmentList = CloneSObjectDAGSelfRefObject.main(
                    JSON.serializePretty(objectAttachmentStructure),
                    wap.ifSelfRefThenFieldName,
                    attachmentRecord,
                    wap.sObjectName
                );
                System.debug('allSelfRefAttachmentList ==== ' +allSelfRefAttachmentList);

                Integer i = 0;
                for(Attachment at :allSelfRefAttachmentList) {
                    planBodyArray.add(generatePlanRecord(wap.sObjectName, CloneSObjectDAGSelfRefObject.generatCounterFileName(i++, wap.sObjectName)));
                }

                attachmentList.addAll(allSelfRefAttachmentList);
            }
        }

        planAttachment.body = Blob.valueOf(JSON.serializePretty(planBodyArray));
        attachmentList.add(planAttachment);

        if(!attachmentList.isEmpty()) {
            insert attachmentList;
        }
        

        
    }

    private static List<Attachment> generateSelfRefAttachments(String fullBody) {
        return null;
    }

    private static Map<String,Object> generatePlanRecord(String objectName, String fileName) {
        Map<String, Object> retObject = new Map<String,Object>();
        retObject.put('saveRefs', true);
        retObject.put('resolveRefs', true);
        retObject.put('sObject', objectName);
        retObject.put('files', new List<String>{fileName});
        return retObject;
    }

    private static Map<String, Object> convertSobjectToMap(sObject sObj, Set<String> fieldsToRef, String sObjectName) {
        Map<String, Object> sObjMap = new Map<String, Object>();
        fieldsToRef = convertToLowerCase(fieldsToRef);
        for(String key : Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap().keySet()) {
            if(sObj.isSet(key) && sObj.get(key) != null) {
                if(fieldsToRef != null && fieldsToRef.contains(key.toLowerCase())) {
                    sObjMap.put(key, '@' + (Id)sObj.get(key));
                } else {
                    sObjMap.put(key, sObj.get(key));
                }
            }
        }
        /* add the following to each map (record)
        "attributes": {
				"type": "Account",
				"referenceId": "AccountRef0"
		}
        */
        Map<String, Object> tempMap = new Map<String, Object>();
        tempMap.put('type', sObjectName);
        tempMap.put('referenceId', String.valueOf(sObj.get('Id')));
        sObjMap.put('attributes', tempMap);
        
        return sObjMap;
    }

    /** 
    converts List if sobject to object list 
    so Contact(id='1',name='abc',accountId='123')
    becomes [{name:'abc',id:'1','accountId':'@123'}]
     */
    private static List<Object> convertSobjectListToList(List<sObject> sObjectList, Set<String> fieldsToRef, String sObjectName) {
        List<Object> listOfSObj = new List<Object>();
        for(sObject sObj : sObjectList) {
            listOfSObj.add(convertSobjectToMap(sObj, fieldsToRef, sObjectName));
        }
        return listOfSObj;
    }

    private static Attachment createAttachmentFile(String sObjectName, String body, Id attachmentRecord) {
        String fileName = getFileName(sObjectName);

        Attachment at = new Attachment(
            ParentId = attachmentRecord,
            body = Blob.valueOf(body),
            Name = fileName
        );
        return at;
    }

    private static Set<String> convertToLowerCase(Set<String> inputSet) {
        Set<String> returnSet = new Set<String>();
        if(inputSet == null || inputSet.isEmpty()) return returnSet;
        for(String str :inputSet) {
            returnSet.add(str.toLowerCase());
        }
        return returnSet;
    }

    private static String getFileName(String sObjectName) {
        return sObjectName + '-' + timeNow + '.json';
    }

}
