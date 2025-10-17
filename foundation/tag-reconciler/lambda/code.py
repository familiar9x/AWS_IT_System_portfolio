"""
Tag Reconciler Lambda
Định kỳ rà soát & đồng bộ tag với AppRegistry
Triggered by EventBridge Scheduler
"""

import boto3
import json
import os
from datetime import datetime

appregistry = boto3.client('servicecatalog-appregistry')
resource_explorer = boto3.client('resource-explorer-2')
config = boto3.client('config')

def lambda_handler(event, context):
    print(f"Starting tag reconciliation at {datetime.now()}")
    
    try:
        # 1. Query tất cả resources có tag awsApplication từ Resource Explorer
        resources = query_resources_with_app_tag()
        
        # 2. Group resources theo awsApplication value
        apps_map = group_resources_by_app(resources)
        
        # 3. Đối chiếu với AppRegistry và associate thiếu
        for app_name, resource_arns in apps_map.items():
            reconcile_application(app_name, resource_arns)
        
        print(f"Tag reconciliation completed successfully")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Tag reconciliation completed',
                'apps_processed': len(apps_map),
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error during tag reconciliation: {str(e)}")
        raise

def query_resources_with_app_tag():
    """Query resources có tag awsApplication từ Resource Explorer"""
    resources = []
    
    try:
        paginator = resource_explorer.get_paginator('search')
        pages = paginator.paginate(
            QueryString='tag.key:awsApplication',
            ViewArn=os.environ['RESOURCE_EXPLORER_VIEW_ARN']
        )
        
        for page in pages:
            resources.extend(page['Resources'])
            
    except Exception as e:
        print(f"Error querying Resource Explorer: {str(e)}")
        
    return resources

def group_resources_by_app(resources):
    """Group resources theo awsApplication tag value"""
    apps_map = {}
    
    for resource in resources:
        # Tìm awsApplication tag
        app_name = None
        if 'Properties' in resource:
            for prop in resource['Properties']:
                if prop['Name'] == 'tag:awsApplication':
                    app_name = prop['Data'][0]['Value']
                    break
        
        if app_name:
            if app_name not in apps_map:
                apps_map[app_name] = []
            apps_map[app_name].append(resource['Arn'])
    
    return apps_map

def reconcile_application(app_name, resource_arns):
    """Đối chiếu và associate resources với AppRegistry Application"""
    try:
        # Kiểm tra Application có tồn tại không
        try:
            app_response = appregistry.get_application(application=app_name)
            app_id = app_response['id']
        except appregistry.exceptions.ResourceNotFoundException:
            print(f"Application {app_name} not found in AppRegistry, skipping")
            return
        
        # Lấy danh sách resources đã associate
        associated_resources = get_associated_resources(app_id)
        
        # Associate các resources còn thiếu
        for arn in resource_arns:
            if arn not in associated_resources:
                try:
                    appregistry.associate_resource(
                        application=app_id,
                        resourceType='CFN_STACK',  # hoặc loại resource khác
                        resource=arn
                    )
                    print(f"Associated {arn} with {app_name}")
                except Exception as e:
                    print(f"Error associating {arn}: {str(e)}")
                    
    except Exception as e:
        print(f"Error reconciling application {app_name}: {str(e)}")

def get_associated_resources(app_id):
    """Lấy danh sách resources đã associate với Application"""
    associated = []
    
    try:
        paginator = appregistry.get_paginator('list_associated_resources')
        pages = paginator.paginate(application=app_id)
        
        for page in pages:
            for resource in page['resources']:
                associated.append(resource['arn'])
                
    except Exception as e:
        print(f"Error getting associated resources: {str(e)}")
        
    return associated
