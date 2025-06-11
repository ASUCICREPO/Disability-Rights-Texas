# API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Configuration](#configuration)
3. [API Endpoints](#api-endpoints)
4. [Services](#services)
5. [Authentication](#authentication)
6. [Examples](#examples)

## Overview

This documentation covers the API integration between the React frontend and Amazon Q Business API. The system provides chat functionality with support for multiple languages, conversation threading, and user feedback.

## Configuration

The application uses environment variables for configuration. These can be set in the `.env` file:

```env
REACT_APP_BASE_API_ENDPOINT=https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod
REACT_APP_API_ENDPOINT=https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod/chat
REACT_APP_FEEDBACK_ENDPOINT=https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod/applications/{applicationId}/conversations/{conversationId}/messages/{messageId}/feedback
REACT_APP_AWS_REGION=us-west-2
REACT_APP_LAMBDA_FUNCTION=arn:aws:lambda:us-west-2:216989103356:function:amazonQBusinessFunctionNew3
```

## API Endpoints

### 1. Chat API
- **Endpoint**: `https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod/chat`
- **Method**: POST
- **Purpose**: Send messages to Amazon Q Business and receive responses
- **Request Body**:
  ```json
  {
    "message": "string",
    "language": "EN" | "ES",
    "conversationId": "string (optional)",
    "parentMessageId": "string (optional)"
  }
  ```
- **Response**:
  ```json
  {
    "systemMessage": "string",
    "systemMessageId": "string",
    "conversationId": "string",
    "userMessageId": "string",
    "sourceAttributions": [
      {
        "title": "string",
        "url": "string"
      }
    ],
    "isNoAnswerFound": boolean
  }
  ```

### 2. Feedback API
- **Endpoint**: `https://7pl17hs2if.execute-api.us-west-2.amazonaws.com/prod/applications/{applicationId}/conversations/{conversationId}/messages/{messageId}/feedback`
- **Method**: POST
- **Purpose**: Submit user feedback for chat responses
- **Request Body**:
  ```json
  {
    "messageUsefulness": {
      "usefulness": "USEFUL" | "NOT_USEFUL",
      "submittedAt": "ISO-8601 timestamp"
    },
    "messageCopiedAt": "ISO-8601 timestamp"
  }
  ```

## Services

### 1. AmazonQService
Main service for interacting with Amazon Q Business API.

#### Methods:

##### sendMessage(message, language, conversationId, parentMessageId, ageGroup)
- **Purpose**: Send a message to the chat API
- **Parameters**:
  - `message`: string - The user's message
  - `language`: string - Language code ('EN' or 'ES')
  - `conversationId`: string (optional) - For conversation threading
  - `parentMessageId`: string (optional) - For message threading
  - `ageGroup`: string (optional) - 'child' or 'adult'
- **Returns**: Promise with API response

##### sendFeedback(feedback, messageId, conversationId)
- **Purpose**: Submit feedback for a chat response
- **Parameters**:
  - `feedback`: string - 'UPVOTED' or 'DOWNVOTED'
  - `messageId`: string - ID of the message being rated
  - `conversationId`: string - ID of the conversation
- **Returns**: Promise with feedback submission result

### 2. TranslationService
Service for handling text translation between languages.

#### Methods:

##### translate(text, targetLanguage)
- **Purpose**: Translate text to target language
- **Parameters**:
  - `text`: string - Text to translate
  - `targetLanguage`: string - Target language code
- **Returns**: Promise with translated text

##### needsTranslation(text, currentLanguage)
- **Purpose**: Check if text needs translation
- **Parameters**:
  - `text`: string - Text to check
  - `currentLanguage`: string - Current language code
- **Returns**: boolean indicating if translation is needed

## Authentication

The API uses AWS Lambda function authentication. The Lambda function ARN is configured in the environment variables:
```
REACT_APP_LAMBDA_FUNCTION=arn:aws:lambda:us-west-2:216989103356:function:amazonQBusinessFunctionNew3
```

## Examples

### Sending a Chat Message
```javascript
const response = await AmazonQService.sendMessage(
  "What are disability rights?",
  "EN",
  "conversation-123",
  "message-456"
);
```

### Submitting Feedback
```javascript
const result = await AmazonQService.sendFeedback(
  "UPVOTED",
  "message-123",
  "conversation-456"
);
```

### Translating Text
```javascript
const translatedText = await TranslationService.translate(
  "Hello, how can I help you?",
  "ES"
);
```

## Debugging

The application includes comprehensive logging for debugging:

1. **API Calls**:
   - Request details
   - Response data
   - Timing information

2. **State Changes**:
   - Conversation state
   - Message processing
   - Language switches

3. **Error Logging**:
   - API errors
   - Translation errors
   - Feedback submission errors

To enable debug logging, set the following in `config.js`:
```javascript
debug: {
  logApiCalls: true,
  logConversationState: true,
  logTranslations: true
}
``` 