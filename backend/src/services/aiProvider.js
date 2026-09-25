/**
 * B.E.A.S.T ACADEMY AI Architecture Specification & Provider Abstraction
 * Section 23 & 24 Compliance:
 * - AI is strictly disabled by default.
 * - Core institutional workflows are 100% independent of AI.
 * - This module defines the provider abstraction layer for future capability injection.
 */

class BaseAIProvider {
  constructor(name) {
    this.name = name;
  }

  async isAvailable() {
    return false;
  }

  async explainConcept(prompt, context) {
    throw new Error('AI capability currently disabled by institutional governance policy.');
  }

  async generateHints(doubtContent) {
    throw new Error('AI capability currently disabled by institutional governance policy.');
  }

  async analyzeWeakness(resultsData) {
    throw new Error('AI capability currently disabled by institutional governance policy.');
  }
}

class DisabledAIProvider extends BaseAIProvider {
  constructor() {
    super('disabled');
  }

  async isAvailable() {
    return false;
  }
}

class AIService {
  constructor() {
    // Free-first principle: default to Disabled provider
    this.provider = new DisabledAIProvider();
    this.isEnabled = false;
  }

  setProvider(provider) {
    this.provider = provider;
  }

  enableAI(flag = false) {
    this.isEnabled = flag;
  }

  getStatus() {
    return {
      enabled: this.isEnabled,
      activeProvider: this.provider.name,
      policy: 'FREE_FIRST_NO_EXTERNAL_AI_DEPENDENCY',
      featuresSupported: [
        'doubt_explanation',
        'concept_summary',
        'question_generation',
        'revision_hints'
      ]
    };
  }

  async explainConcept(prompt, context = {}) {
    if (!this.isEnabled) {
      return {
        success: false,
        message: 'AI Service is currently disabled by Academy policy. Core education operates human-first.'
      };
    }
    return await this.provider.explainConcept(prompt, context);
  }
}

const aiService = new AIService();

module.exports = {
  BaseAIProvider,
  DisabledAIProvider,
  aiService
};
