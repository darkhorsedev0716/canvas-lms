/*
 * Copyright (C) 2018 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import I18n from 'i18n!react_developer_keys'
import $ from 'jquery'
import Button from '@instructure/ui-buttons/lib/components/Button'
import CloseButton from '@instructure/ui-buttons/lib/components/CloseButton'
import Heading from '@instructure/ui-elements/lib/components/Heading'
import Modal, {ModalHeader, ModalBody} from '@instructure/ui-overlays/lib/components/Modal'
import Spinner from '@instructure/ui-elements/lib/components/Spinner'
import View from '@instructure/ui-layout/lib/components/View'
import React from 'react'
import PropTypes from 'prop-types'
import DeveloperKeyFormFields from './NewKeyForm'
import NewKeyFooter from './NewKeyFooter'
import LtiKeyFooter from './LtiKeyFooter'

export default class DeveloperKeyModal extends React.Component {
  developerKeyUrl() {
    if (this.developerKey()) {
      return `/api/v1/developer_keys/${this.developerKey().id}`
    }
    return `/api/v1/accounts/${this.props.ctx.params.contextId}/developer_keys`
  }

  developerKey() {
    return this.props.createOrEditDeveloperKeyState.developerKey
  }

  modalTitle() {
    return this.developerKey() ? I18n.t('Create developer key') : I18n.t('Edit developer key')
  }

  get submissionForm () {
    return this.newForm ? this.newForm.keyForm : <form />
  }

  get requireScopes () {
    return this.newForm && this.newForm.requireScopes
  }

  get testClusterOnly () {
    return this.newForm && this.newForm.testClusterOnly
  }

  submitForm = () => {
    const method = this.developerKey() ? 'put' : 'post'
    const formData = new FormData(this.submissionForm)

    if (!this.requireScopes) {
      formData.delete('developer_key[scopes][]')
      formData.append('developer_key[require_scopes]', false)
    } else if (this.props.selectedScopes.length === 0) {
      $.flashError(I18n.t('At least one scope must be selected.'))
      return
    } else {
      const scopesArrayKey = 'developer_key[scopes][]'

      this.props.selectedScopes.forEach((scope) => {
        formData.append(scopesArrayKey, scope)
      })
      formData.append('developer_key[require_scopes]', true)
    }

    if (!this.testClusterOnly) {
      formData.append('developer_key[test_cluster_only]', false)
    }

    this.props.store.dispatch(
      this.props.actions.createOrEditDeveloperKey(formData, this.developerKeyUrl(), method)
    )
  }

  get isLtiKey() {
    return this.props.createLtiKeyState.ltiKey
  }

  modalBody() {
    if (this.props.createOrEditDeveloperKeyState.developerKeyCreateOrEditPending) {
      return this.spinner()
    }
    return this.developerKeyForm()
  }

  modalFooter() {
    if (this.isLtiKey) {
      return(
        <LtiKeyFooter
          onCancelClick={this.closeModal}
          onSaveClick={this.submitForm}
          customizing={this.props.createLtiKeyState.customizing}
          ltiKeysSetCustomizing={this.props.actions.ltiKeysSetCustomizing}
          dispatch={this.props.store.dispatch}
        />
      )
    }
    return(
      <NewKeyFooter
        onCancelClick={this.closeModal}
        onSaveClick={this.submitForm}
      />
    )
  }

  spinner() {
    return (
      <View
        as="div"
        textAlign="center"
      >
        <Spinner title={I18n.t('Creating Key')} margin="0 0 0 medium" />
      </View>
    )
  }

  developerKeyForm() {
    const {
      createLtiKeyState,
      availableScopes,
      availableScopesPending,
      createOrEditDeveloperKeyState: { developerKey }
    } = this.props;

    return <DeveloperKeyFormFields
      ref={this.setNewFormRef}
      developerKey={developerKey}
      availableScopes={availableScopes}
      availableScopesPending={availableScopesPending}
      dispatch={this.props.store.dispatch}
      listDeveloperKeyScopesSet={this.props.actions.listDeveloperKeyScopesSet}
      createLtiKeyState={createLtiKeyState}
    />
  }

  setNewFormRef = node => { this.newForm = node }
  modalContainerRef = node => { this.modalContainer = node }

  modalIsOpen() {
    return this.props.createOrEditDeveloperKeyState.developerKeyModalOpen
  }

  closeModal = () => {
    const { actions, store } = this.props

    store.dispatch(actions.ltiKeysSetCustomizing(false))
    store.dispatch(actions.developerKeysModalClose())
    store.dispatch(actions.editDeveloperKey())
  }

  render() {
    return (
      <div ref={this.modalContainerRef}>
        <Modal
          open={this.modalIsOpen()}
          onDismiss={this.closeModal}
          size="fullscreen"
          label={this.modalTitle()}
        >
          <ModalHeader>
            <CloseButton placement="end" onClick={this.closeModal}>
              {I18n.t('Cancel')}
            </CloseButton>
            <Heading>{I18n.t('Key Settings')}</Heading>
          </ModalHeader>
          <ModalBody>{this.modalBody()}</ModalBody>
          {this.modalFooter()}
        </Modal>
      </div>
    )
  }
}

DeveloperKeyModal.propTypes = {
  availableScopes: PropTypes.objectOf(PropTypes.arrayOf(
    PropTypes.shape({
      resource: PropTypes.string,
      scope: PropTypes.string
    })
  )).isRequired,
  store: PropTypes.shape({
    dispatch: PropTypes.func.isRequired
  }).isRequired,
  actions: PropTypes.shape({
    ltiKeysSetCustomizing: PropTypes.func.isRequired,
    createOrEditDeveloperKey: PropTypes.func.isRequired,
    developerKeysModalClose: PropTypes.func.isRequired,
    editDeveloperKey: PropTypes.func.isRequired,
    listDeveloperKeyScopesSet: PropTypes.func.isRequired
  }).isRequired,
  createLtiKeyState: PropTypes.shape({
    ltiKey: PropTypes.bool.isRequired,
    customizing: PropTypes.bool.isRequired
  }).isRequired,
  createOrEditDeveloperKeyState: PropTypes.shape({
    developerKeyCreateOrEditSuccessful: PropTypes.bool.isRequired,
    developerKeyCreateOrEditFailed: PropTypes.bool.isRequired,
    developerKeyCreateOrEditPending: PropTypes.bool.isRequired,
    developerKeyModalOpen: PropTypes.bool.isRequired,
    developerKey: DeveloperKeyFormFields.propTypes.developerKey
  }).isRequired,
  availableScopesPending: PropTypes.bool.isRequired,
  ctx: PropTypes.shape({
    params: PropTypes.shape({
      contextId: PropTypes.string.isRequired
    })
  }).isRequired,
  selectedScopes: PropTypes.arrayOf(PropTypes.string).isRequired
}
