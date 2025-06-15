import React, { useState, useEffect } from "react";
import { Grid, Avatar, Typography, Box, Link, IconButton } from "@mui/material";
import ThumbUpIcon from '@mui/icons-material/ThumbUp';
import ThumbDownIcon from '@mui/icons-material/ThumbDown';
import AmazonQService from "../services/amazonQService";
import BotAvatar from "../Assets/BotAvatar.svg";
import { ALLOW_MARKDOWN_BOT, ALLOW_FEEDBACK } from "../utilities/constants";
import ReactMarkdown from "react-markdown";

const BotResponse = ({ message, citations = [], messageId = "", conversationId = "", state = "RECEIVED" }) => {
  // Debug logging for initial props
  console.log('BotResponse received props:', {
    messageId,
    conversationId,
    state,
    ALLOW_FEEDBACK,
    messageLength: message?.length
  });

  // Ensure message is a string
  const safeMessage = message || "";
  const [feedback, setFeedback] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  // Debug logging for state changes
  useEffect(() => {
    console.log('BotResponse state updated:', {
      messageId,
      conversationId,
      state,
      feedback,
      isSubmitting
    });
  }, [messageId, conversationId, state, feedback, isSubmitting]);
  
  // Process the message to handle line breaks
  const formattedMessage = safeMessage.replace(/\n/g, '<br>');
  
  // Filter out duplicate sources based on title
  const uniqueCitations = citations ? Array.from(
    new Map(citations.map(citation => [citation.title, citation])).values()
  ) : [];
  
  console.log('Citations processing:', {
    originalCount: citations?.length || 0,
    uniqueCount: uniqueCitations.length,
    uniqueCitations,
    titles: uniqueCitations.map(c => c.title)
  });
  
  // Feedback handler
  const handleFeedback = async (newFeedback) => {
    if (isSubmitting || !messageId || !conversationId) {
      console.log('Feedback submission blocked:', {
        isSubmitting,
        messageId,
        conversationId
      });
      return;
    }
    
    // If the same button is clicked again, remove the feedback
    const updatedFeedback = feedback === newFeedback ? null : newFeedback;
    
    setIsSubmitting(true);
    console.log('Sending feedback:', {
      feedback: updatedFeedback,
      messageId,
      conversationId
    });
    
    try {
      const result = await AmazonQService.sendFeedback(updatedFeedback, messageId, conversationId);
      
      if (result.success) {
        setFeedback(updatedFeedback);
        console.log(`Feedback ${updatedFeedback} submitted successfully`);
      } else {
        console.error('Feedback submission failed:', result.error);
      }
    } catch (error) {
      console.error('Error submitting feedback:', error);
      setFeedback(feedback);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Check if the bot is currently thinking
  const isThinking = state === "PROCESSING";

  // TEMP: Show feedback buttons for debugging even if IDs are missing
  const shouldShowFeedback = ALLOW_FEEDBACK && !isThinking;
  console.log('Feedback button visibility conditions:', {
    shouldShowFeedback,
    ALLOW_FEEDBACK,
    isThinking,
    hasMessageId: !!messageId,
    hasConversationId: !!conversationId,
    messageId,
    conversationId
  });

  if (isThinking) {
    return (
      <Grid container direction="row" justifyContent="flex-start" alignItems="flex-end">
        <Grid item>
          <Avatar alt="Bot Avatar" src={BotAvatar} />
        </Grid>
        <Grid item className="botMessage" sx={{ 
          backgroundColor: (theme) => theme.palette.background.botMessage,
          borderRadius: 2,
          p: 2,
          maxWidth: '80%',
          display: 'flex',
          alignItems: 'center',
          gap: 1
        }}>
          <Typography variant="body2" sx={{ color: 'text.secondary' }}>
            Thinking
          </Typography>
          <Box sx={{ display: 'flex', gap: 0.5 }}>
            <Box sx={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              backgroundColor: 'primary.main',
              animation: 'typing 1s infinite ease-in-out',
              '&:nth-of-type(1)': { animationDelay: '0.2s' },
              '&:nth-of-type(2)': { animationDelay: '0.4s' },
              '&:nth-of-type(3)': { animationDelay: '0.6s' }
            }} />
            <Box sx={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              backgroundColor: 'primary.main',
              animation: 'typing 1s infinite ease-in-out',
              '&:nth-of-type(1)': { animationDelay: '0.2s' },
              '&:nth-of-type(2)': { animationDelay: '0.4s' },
              '&:nth-of-type(3)': { animationDelay: '0.6s' }
            }} />
            <Box sx={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              backgroundColor: 'primary.main',
              animation: 'typing 1s infinite ease-in-out',
              '&:nth-of-type(1)': { animationDelay: '0.2s' },
              '&:nth-of-type(2)': { animationDelay: '0.4s' },
              '&:nth-of-type(3)': { animationDelay: '0.6s' }
            }} />
          </Box>
        </Grid>
      </Grid>
    );
  }

  return (
    <Grid container direction="row" justifyContent="flex-start" alignItems="flex-end">
      <Grid item>
        <Avatar alt="Bot Avatar" src={BotAvatar} />
      </Grid>
      <Grid item className="botMessage" sx={{ 
        backgroundColor: (theme) => theme.palette.background.botMessage,
        borderRadius: 2,
        p: 2,
        maxWidth: '80%'
      }}>
        {ALLOW_MARKDOWN_BOT ? (
          <ReactMarkdown>{safeMessage}</ReactMarkdown>
        ) : (
          <div dangerouslySetInnerHTML={{ __html: formattedMessage }} />
        )}
        
        {/* Citations */}
        {uniqueCitations && uniqueCitations.length > 0 && (
          <Box mt={1}>
            <Typography 
              variant="caption" 
              color="textSecondary"
              sx={{ fontSize: '0.9rem' }}
            >
              Sources:
            </Typography>
            {uniqueCitations.map((citation, index) => (
              <Box key={index}>
                <Link 
                  href={citation.url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  sx={{ 
                    fontSize: '0.9rem',
                    color: '#0066cc',
                    textDecoration: 'underline',
                    '&:hover': {
                      color: '#004499'
                    }
                  }}
                >
                  {citation.title}
                </Link>
              </Box>
            ))}
          </Box>
        )}
        
        {/* Feedback buttons */}
        {shouldShowFeedback && (
          <Box 
            display="flex" 
            justifyContent="flex-end" 
            mt={1}
            sx={{
              borderTop: '1px solid',
              borderColor: 'divider',
              pt: 1
            }}
          >
            <IconButton
              onClick={() => handleFeedback('UPVOTED')}
              disabled={isSubmitting}
              sx={{
                color: feedback === 'UPVOTED' ? 'primary.main' : 'action.disabled',
                '&:hover': {
                  color: 'primary.main'
                }
              }}
              aria-label="Thumbs up"
            >
              <ThumbUpIcon />
            </IconButton>
            <IconButton
              onClick={() => handleFeedback('DOWNVOTED')}
              disabled={isSubmitting}
              sx={{
                color: feedback === 'DOWNVOTED' ? 'primary.main' : 'action.disabled',
                '&:hover': {
                  color: 'primary.main'
                }
              }}
              aria-label="Thumbs down"
            >
              <ThumbDownIcon />
            </IconButton>
          </Box>
        )}
      </Grid>
    </Grid>
  );
};

export default BotResponse;