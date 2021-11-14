module.exports = {
  ignorePatterns: ['coverage/'],
  env: {
    es2021: true,
    mocha: true
  },
  extends: [
    'standard'
  ],
  parser: 'babel-eslint',
  parserOptions: {
    ecmaVersion: 12,
    sourceType: 'module'
  },
  rules: {
  }
}
