// Configuration for API endpoints
const CONFIG = {
  api: {
    baseEndpoint: process.env.REACT_APP_BASE_API_ENDPOINT,
    endpoint: process.env.REACT_APP_API_ENDPOINT,
    feedbackEndpoint: process.env.REACT_APP_FEEDBACK_ENDPOINT,
    region: process.env.REACT_APP_AWS_REGION,
    lambdaFunction: process.env.REACT_APP_LAMBDA_FUNCTION,
    applicationId: process.env.REACT_APP_APPLICATION_ID
  },
  ui: {
    noAnswerMessage: {
      EN: "I don't have enough information to answer that question.",
      ES: "No tengo suficiente información para responder a esa pregunta."
    },
    loadingMessage: {
      EN: "Thinking...",
      ES: "Pensando..."
    },
    errorMessage: {
      EN: "Sorry, I encountered an error. Please try again later.",
      ES: "Lo siento, encontré un error. Por favor, inténtalo de nuevo más tarde."
    },
    emptyStateMessage: {
      EN: "Start a conversation with Amazon Q Business",
      ES: "Inicia una conversación with Amazon Q Business"
    },
    translationIndicator: {
      EN: "Automatic translation",
      ES: "Traducción automática"
    }
  },
  translation: {
    defaultLanguage: process.env.REACT_APP_DEFAULT_LANGUAGE || 'EN'
  },
  supportedLanguages: ['EN', 'ES'],
  defaultLanguage: process.env.REACT_APP_DEFAULT_LANGUAGE || 'EN',
  debug: {
    logApiCalls: true,
    logConversationState: true,
    logTranslations: true
  }
};

console.log('Amazon Q Business API Configuration:', {
  endpoint: CONFIG.api.endpoint,
  region: CONFIG.api.region,
  supportedLanguages: CONFIG.supportedLanguages
});

export default CONFIG;