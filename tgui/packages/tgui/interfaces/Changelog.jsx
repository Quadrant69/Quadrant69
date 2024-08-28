import dateformat from 'dateformat';
import yaml from 'js-yaml';
import { Component, Fragment } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Icon,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

const icons = {
  add: { icon: 'check-circle', color: 'green' },
  admin: { icon: 'user-shield', color: 'purple' },
  balance: { icon: 'balance-scale-right', color: 'yellow' },
  bugfix: { icon: 'bug', color: 'green' },
  code_imp: { icon: 'code', color: 'green' },
  config: { icon: 'cogs', color: 'purple' },
  expansion: { icon: 'check-circle', color: 'green' },
  experiment: { icon: 'radiation', color: 'yellow' },
  image: { icon: 'image', color: 'green' },
  imageadd: { icon: 'tg-image-plus', color: 'green' },
  imagedel: { icon: 'tg-image-minus', color: 'red' },
  qol: { icon: 'hand-holding-heart', color: 'green' },
  refactor: { icon: 'tools', color: 'green' },
  rscadd: { icon: 'check-circle', color: 'green' },
  rscdel: { icon: 'times-circle', color: 'red' },
  server: { icon: 'server', color: 'purple' },
  sound: { icon: 'volume-high', color: 'green' },
  soundadd: { icon: 'tg-sound-plus', color: 'green' },
  sounddel: { icon: 'tg-sound-minus', color: 'red' },
  spellcheck: { icon: 'spell-check', color: 'green' },
  tgs: { icon: 'toolbox', color: 'purple' },
  tweak: { icon: 'wrench', color: 'green' },
  unknown: { icon: 'info-circle', color: 'label' },
  wip: { icon: 'hammer', color: 'orange' },
};

export class Changelog extends Component {
  constructor(props) {
    super(props);
    this.state = {
      data: 'Loading changelog data...',
      selectedDate: '',
      selectedIndex: 0,
      upstreamChangelog: false, // QUADRANT69 EDIT ADDITION
    };
    this.dateChoices = [];
    this.dateChoices_q69 = [];
  }

  setData(data) {
    this.setState({ data });
  }

  setSelectedDate(selectedDate) {
    this.setState({ selectedDate });
  }

  setSelectedIndex(selectedIndex) {
    this.setState({ selectedIndex });
  }

  // QUADRANT69 EDIT ADDITION START
  setupstreamChangelog(upstreamChangelog) {
    this.setState({ upstreamChangelog });
  }
  // QUADRANT69 EDIT ADDITION END

  getData = (date, upstreamChangelog, attemptNumber = 1) => {
    const { act } = useBackend();
    const self = this;
    const maxAttempts = 6;

    // QUADRANT69 EDIT ADDITION START
    let assetToResolve = date + '.yml' + '_q69';
    if (upstreamChangelog) {
      assetToResolve = date + '.yml';
    }
    // QUADRANT69 EDIT ADDITION END

    if (attemptNumber > maxAttempts) {
      return this.setData(
        'Failed to load data after ' + maxAttempts + ' attempts',
      );
    }

    act('get_month', { date: date, upstreamChangelog: upstreamChangelog }); // QUADRANT69 EDIT CHANGE START - ORIGINAL:
    // act('get_month', { date });
    // QUADRANT69 EDIT CHANGE END

    // QUADRANT69 REMOVAL START - (Original code has no handlers for HTTP errors)
    /*
    fetch(resolveAsset(date + '.yml')).then(async (changelogData) => {
      const result = await changelogData.text();
      const errorRegex = /^Cannot find/;

      if (errorRegex.test(result)) {
        const timeout = 50 + attemptNumber * 50;

        self.setData('Loading changelog data' + '.'.repeat(attemptNumber + 3));
        setTimeout(() => {
          self.getData(date, attemptNumber + 1);
        }, timeout);
      } else {
        self.setData(yaml.load(result, { schema: yaml.CORE_SCHEMA }));
      }
    });
    */
 // QUADRANT69 REMOVAL END
 // QUADRANT69 EDIT ADDITION START
    fetch(resolveAsset(assetToResolve))
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.text();
      })
      .then(async (result) => {
        const errorRegex = /^Cannot find/;

        if (errorRegex.test(result)) {
          const timeout = 150 + attemptNumber * 150;

          self.setData('Loading changelog data' + '.'.repeat(attemptNumber + 3));
          setTimeout(() => {
            self.getData(date, upstreamChangelog, attemptNumber + 1);
          }, timeout);
        } else {
          self.setData(yaml.load(result, { schema: yaml.CORE_SCHEMA }));
        }
      })
      .catch((error) => {
          const timeout = 150 + attemptNumber * 150;
          self.setData('Error loading changelog data. Retrying...' + 'x' + attemptNumber);
          setTimeout(() => {
            self.getData(date, upstreamChangelog, attemptNumber + 1);
          }, timeout);
      });
      // QUADRANT69 EDIT ADDITION END
  };

  componentDidMount() {
    const {
      data: { dates = [], dates_q69 = [], upstreamChangelog },
    } = useBackend();

    if (dates) {
      dates.forEach((date) =>
        this.dateChoices.push(dateformat(date, 'mmmm yyyy', true)),
      );
      if (upstreamChangelog) {
        this.setSelectedDate(this.dateChoices[0]);
        this.getData(dates[0], true);
      }
    }

    if (dates_q69) {
      dates_q69.forEach((date) =>
        this.dateChoices_q69.push(dateformat(date, 'mmmm yyyy', true)),
      );
      if (!upstreamChangelog) {
        this.setSelectedDate(this.dateChoices_q69[0]);
        this.getData(dates_q69[0], false);
      }
    }
  }

  render() {
    const { data, selectedDate, selectedIndex, upstreamChangelog } = this.state; // QUADRANT69 EDIT CHANGE START - ORIGINAL:
    // const { data, selectedDate, selectedIndex } = this.state;
    // QUADRANT69 EDIT CHANGE END
    const {
      data: { dates = [], dates_q69 = [] },
    } = useBackend();
    const { dateChoices, dateChoices_q69 } = this;

    const dateDropdown = ((dateChoices.length > 0 && upstreamChangelog) || (dateChoices_q69.length > 0 && !upstreamChangelog)) && (
      <Stack mb={1}>
        <Stack.Item>
          <Button
            className="Changelog__Button"
            disabled={selectedIndex === 0}
            icon={'chevron-left'}
            onClick={() => {
              const index = selectedIndex - 1;

              this.setData('Loading changelog data...');
              this.setSelectedIndex(index);
              if (upstreamChangelog) {
                this.setSelectedDate(dateChoices[index]);
              }
              else {
                this.setSelectedDate(dateChoices_q69[index]);
              }
              window.scrollTo(
                0,
                document.body.scrollHeight ||
                  document.documentElement.scrollHeight,
              );
              { /* return this.getData(dates[index]); // ORIGINAL */ }
              { /* QUADRANT69 EDIT CHANGE BEGIN*/ }
              return this.getData(upstreamChangelog ? dates[index] : dates_q69[index], upstreamChangelog);
              { /* QUADRANT69 EDIT CHANGE END */ }
            }}
          />
        </Stack.Item>
        <Stack.Item>
          <Dropdown
            autoScroll={false}
            options={upstreamChangelog ? dateChoices : dateChoices_q69}
            onSelected={(value) => {
              const index = upstreamChangelog ? dateChoices.indexOf(value) : dateChoices_q69.indexOf(value);
              this.setData('Loading changelog data...');
              this.setSelectedIndex(index);
              this.setSelectedDate(value);
              window.scrollTo(
                0,
                document.body.scrollHeight ||
                  document.documentElement.scrollHeight,
              );
              { /* return this.getData(dates[index]); // ORIGINAL */ }
              { /* QUADRANT69 EDIT CHANGE BEGIN*/ }
              return this.getData(upstreamChangelog ? dates[index] : dates_q69[index], upstreamChangelog);
              { /* QUADRANT69 EDIT CHANGE END */ }
            }}
            selected={selectedDate}
            width="150px"
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            className="Changelog__Button"
            disabled={selectedIndex === (upstreamChangelog ? dateChoices.length : dateChoices_q69.length) - 1}
            icon={'chevron-right'}
            onClick={() => {
              const index = selectedIndex + 1;

              this.setData('Loading changelog data...');
              this.setSelectedIndex(index);
              if (upstreamChangelog) {
                this.setSelectedDate(dateChoices[index]);
              }
              else {
                this.setSelectedDate(dateChoices_q69[index]);
              }
              window.scrollTo(
                0,
                document.body.scrollHeight ||
                  document.documentElement.scrollHeight,
              );
              { /* return this.getData(dates[index]); // ORIGINAL */ }
              { /* QUADRANT69 EDIT CHANGE BEGIN*/ }
              return this.getData(upstreamChangelog ? dates[index] : dates_q69[index], upstreamChangelog);
              { /* QUADRANT69 EDIT CHANGE END */ }
            }}
          />
        </Stack.Item>
        {/* QUADRANT69 EDIT ADDITION START */}
        <Stack.Item>
          <Button.Checkbox
            checked={upstreamChangelog}
            onClick={() => {
              const index = selectedIndex;
              const altLog = !upstreamChangelog;
              this.setupstreamChangelog(altLog);
              this.setData('Loading changelog data...');
              this.setSelectedIndex(index);
              if (upstreamChangelog) {
                this.setSelectedDate(dateChoices[index]);
              }
              else {
                this.setSelectedDate(dateChoices_q69[index]);
              }
              window.scrollTo(
                0,
                document.body.scrollHeight ||
                  document.documentElement.scrollHeight,
              );
              return this.getData(altLog ? dates[index] : dates_q69[index], altLog);
            }}
            content="Show NovaSector ChangeLog"
          />
        </Stack.Item>
        {/* QUADRANT69 EDIT ADDITION END */}
      </Stack>
    );

    const header = (
      <Section>
        {/* <h1>Nova Sector</h1> // ORIGINAL */}
        {/* QUADRANT69 EDIT CHANGE BEGIN - Rebranding */}
        <h1>Quadrant69</h1>
        {/* QUADRANT69 EDIT CHANGE END */}
        <p>
          <b>Thanks to: </b>
          Traditional Games 13, Skyrat Station 13, Baystation 12, /vg/station,
          NTstation, CDK Station devs, FacepunchStation, GoonStation devs, the
          original Space Station 13 developers, Invisty for the title image and
          the countless others who have contributed to the game.
        </p>
        {/* QUADRANT69 EDIT CHANGE BEGIN*/}

        {/* <p>
          {'Current project maintainers can be found '}
          <a href="https://github.com/NovaSector?tab=members">here</a>
          {', recent GitHub contributors can be found '}
          <a href="https://github.com/NovaSector/NovaSector/pulse/monthly">
            here
          </a>
          .
        </p> */}
        {/* QUADRANT69 EDIT CHANGE END */}

        {/* <p>
          {'You can also join our forums '}
          <a href="">here</a>.
        </p> */}
        {dateDropdown}
      </Section>
    );

    const footer = (
      <Section>
        {dateDropdown}
        <h3>GoonStation 13 Development Team</h3>
        <p>
          <b>Coders: </b>
          Stuntwaffle, Showtime, Pantaloons, Nannek, Keelin, Exadv1, hobnob,
          Justicefries, 0staf, sniperchance, AngriestIBM, BrianOBlivion
        </p>
        <p>
          <b>Spriters: </b>
          Supernorn, Haruhi, Stuntwaffle, Pantaloons, Rho, SynthOrange, I Said
          No
        </p>
        <p>
          Traditional Games Space Station 13 is thankful to the GoonStation 13
          Development Team for its work on the game up to the
          {' r4407 release. The changelog for changes up to r4407 can be seen '}
          <a href="https://wiki.ss13.co/Pre-2016_Changelog#April_2010">here</a>.
        </p>
        <p>
          {'Except where otherwise noted, Goon Station 13 is licensed under a '}
          <a href="https://creativecommons.org/licenses/by-nc-sa/3.0/">
            Creative Commons Attribution-Noncommercial-Share Alike 3.0 License
          </a>
          {'. Rights are currently extended to '}
          <a href="http://forums.somethingawful.com/">SomethingAwful Goons</a>
          {' only.'}
        </p>
        <h3>Traditional Games Space Station 13 License</h3>
        <p>
          {'All code after '}
          <a
            href={
              'https://github.com/tgstation/tgstation/commit/' +
              '333c566b88108de218d882840e61928a9b759d8f'
            }
          >
            commit 333c566b88108de218d882840e61928a9b759d8f on 2014/31/12 at
            4:38 PM PST
          </a>
          {' is licensed under '}
          <a href="https://www.gnu.org/licenses/agpl-3.0.html">GNU AGPL v3</a>
          {'. All code before that commit is licensed under '}
          <a href="https://www.gnu.org/licenses/gpl-3.0.html">GNU GPL v3</a>
          {', including tools unless their readme specifies otherwise. See '}
          <a href="https://github.com/tgstation/tgstation/blob/master/LICENSE">
            LICENSE
          </a>
          {' and '}
          <a href="https://github.com/tgstation/tgstation/blob/master/GPLv3.txt">
            GPLv3.txt
          </a>
          {' for more details.'}
        </p>
        <p>
          The TGS DMAPI API is licensed as a subproject under the MIT license.
          {' See the footer of '}
          <a
            href={
              'https://github.com/tgstation/tgstation/blob/master' +
              '/code/__DEFINES/tgs.dm'
            }
          >
            code/__DEFINES/tgs.dm
          </a>
          {' and '}
          <a
            href={
              'https://github.com/tgstation/tgstation/blob/master' +
              '/code/modules/tgs/LICENSE'
            }
          >
            code/modules/tgs/LICENSE
          </a>
          {' for the MIT license.'}
        </p>
        <p>
          {'All assets including icons and sound are under a '}
          <a href="https://creativecommons.org/licenses/by-sa/3.0/">
            Creative Commons 3.0 BY-SA license
          </a>
          {' unless otherwise indicated.'}
        </p>
      </Section>
    );

    const changes =
      typeof data === 'object' &&
      Object.keys(data).length > 0 &&
      Object.entries(data)
        .reverse()
        .map(([date, authors]) => (
          <Section key={date} title={dateformat(date, 'd mmmm yyyy', true)}>
            <Box ml={3}>
              {Object.entries(authors).map(([name, changes]) => (
                <Fragment key={name}>
                  <h4>{name} changed:</h4>
                  <Box ml={3}>
                    <Table>
                      {changes.map((change) => {
                        const changeType = Object.keys(change)[0];
                        return (
                          <Table.Row key={changeType + change[changeType]}>
                            <Table.Cell
                              className={classes([
                                'Changelog__Cell',
                                'Changelog__Cell--Icon',
                              ])}
                            >
                              <Icon
                                color={
                                  icons[changeType]
                                    ? icons[changeType].color
                                    : icons['unknown'].color
                                }
                                name={
                                  icons[changeType]
                                    ? icons[changeType].icon
                                    : icons['unknown'].icon
                                }
                              />
                            </Table.Cell>
                            <Table.Cell className="Changelog__Cell">
                              {change[changeType]}
                            </Table.Cell>
                          </Table.Row>
                        );
                      })}
                    </Table>
                  </Box>
                </Fragment>
              ))}
            </Box>
          </Section>
        ));

    return (
      <Window title="Changelog" width={675} height={650}>
        <Window.Content scrollable>
          {header}
          {changes}
          {typeof data === 'string' && <p>{data}</p>}
          {footer}
        </Window.Content>
      </Window>
    );
  }
}
