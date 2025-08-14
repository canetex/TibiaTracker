import React from 'react'
import logger from '../lib/logger'

type ErrorBoundaryState = { hasError: boolean }

export default class ErrorBoundary extends React.Component<React.PropsWithChildren, ErrorBoundaryState> {
  constructor(props: React.PropsWithChildren) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true }
  }

  componentDidCatch(error: unknown, info: unknown) {
    logger.error('ErrorBoundary capturou um erro:', error, info)
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="container mx-auto p-6">
          <div className="tibia-card p-6">
            <h2 className="text-xl font-bold mb-2">Ocorreu um erro</h2>
            <p className="text-muted-foreground">Tente recarregar a página.</p>
          </div>
        </div>
      )
    }
    return this.props.children
  }
} 