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

import React from 'react'
import { shallow } from 'enzyme'
import { merge } from 'lodash'
import OutcomesImporter from '../OutcomesImporter'

jest.mock('../../shared/FlashAlert');
import { showFlashAlert } from '../../shared/FlashAlert'

jest.mock('../apiClient');
import * as apiClient from '../apiClient'

jest.useFakeTimers()

const defaultProps = (props = {}) => (
  merge({
    mount: null,
    disableOutcomeViews: () => {},
    resetOutcomeViews: () => {},
    file: {},
    contextUrlRoot: '/accounts/1'
  }, props)
)

it('renders the OutcomesImporter component', () => {
  const modal = shallow(<OutcomesImporter {...defaultProps}/>)
  expect(modal.exists()).toBe(true)
})

it('disables the Outcome Views when upload starts', () => {
  const disableOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ disableOutcomeViews })}/>)
  apiClient.createImport.mockReturnValue(Promise.resolve({data: {id: 3}}))
  modal.instance().beginUpload()
  expect(disableOutcomeViews).toBeCalled()
})

it('resets the Outcome Views when upload is complete', () => {
  const resetOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ resetOutcomeViews })}/>)
  modal.instance().completeUpload(10)
  expect(resetOutcomeViews).toBeCalled()
})

it('shows a flash alert when upload successfully completes', () => {
  const resetOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ resetOutcomeViews })}/>)
  modal.instance().completeUpload(0)
  expect(showFlashAlert).toBeCalledWith({
    type: 'success',
    message: 'Your outcomes were successfully imported.'
  })
})

it('shows a flash alert when upload fails', () => {
  const resetOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ resetOutcomeViews })}/>)
  modal.instance().completeUpload(10)
  expect(showFlashAlert).toBeCalledWith({
    type: 'error',
    message: 'There were errors with your import, please examine your file and attempt the upload again. Check your email for more details.'
  })
})

it('uploads file when the upload begins', () => {
  const disableOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ disableOutcomeViews })}/>)
  apiClient.createImport.mockReturnValue(Promise.resolve({data: {id: 3}}))
  modal.instance().beginUpload()
  expect(apiClient.createImport).toBeCalledWith('/accounts/1', {})
})

it('starts polling for import status after the upload begins', () => {
  const disableOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ disableOutcomeViews })}/>)
  apiClient.createImport.mockReturnValue(Promise.resolve({data: {id: 3}}))
  apiClient.queryImportStatus.mockReturnValue(Promise.resolve({data: {workflow_state: 'succeeded', processing_errors: []}}))
  modal.instance().beginUpload()
  expect(setInterval).toHaveBeenLastCalledWith(expect.any(Function), 1000)
  jest.advanceTimersByTime(2000);
  expect(apiClient.queryImportStatus).toHaveBeenLastCalledWith('/accounts/1', 3)
})

it('completes upload when status returns succeeded or failed', async () => {
  const resetOutcomeViews = jest.fn()
  const modal = shallow(<OutcomesImporter {...defaultProps({ resetOutcomeViews })}/>)
  apiClient.queryImportStatus.mockReturnValue(Promise.resolve({data: {workflow_state: 'succeeded', processing_errors: []}}))
  modal.instance().pollImportStatus(0)
  await jest.advanceTimersByTime(2000);
  expect(resetOutcomeViews).toBeCalled()
})
