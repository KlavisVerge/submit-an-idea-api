require('dotenv/config');
const AWS = require('aws-sdk');
const uuidv4 = require('uuid/v4');
AWS.config.update({region: 'us-east-1'});
const ddb = new AWS.DynamoDB({apiVersion: '2012-10-08'});

exports.handler = (event, context) => {
    if(event){
        if(!event.body){
            event.body = {};
        }else if(typeof event.body === 'string'){
            event.body = JSON.parse(event.body);
        }
    }
    const required = ['idea', 'email'].filter((property) => !event.body[property]);
    if(required.length > 0){
        return Promise.reject({
            statusCode: 400,
            message: `Required properties missing: "${required.join('", "')}".`
        });
    }

    var params = {
        TableName: 'submit-an-idea',
        Item: {
            email: {S: event.body.idea.email > 1000 ? event.body.email.substring(0, 999) : event.body.email},
            rangekey: {S: new Date() + uuidv4()},
            message: {S: event.body.idea.length > 1000 ? event.body.idea.substring(0, 999) : event.body.idea},
            received: {S: new Date()}
        }
    };
    
    ddb.putItem(params, function(err, data) {
        if (err) {
            return context.succeed({
                statusCode: 200,
                body: 'There was an error processing your idea. Please try again later.',
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Methods': 'POST',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,XAmz-Security-Token',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        } else {
            return context.succeed({
                statusCode: 200,
                body: 'Your idea was successfully received!',
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Methods': 'POST',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,XAmz-Security-Token',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
    });
}